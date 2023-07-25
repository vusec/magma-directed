#define _POSIX_C_SOURCE 200112L
#define _GNU_SOURCE

#include "canary.h"
#include "common.h"
#include <fcntl.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#include <linux/limits.h>
#include <sys/wait.h>

enum EXIT_CODES {
    SELECT_INVALID_ARGS_ERROR = 1,
    SELECT_FILE_ERROR,
    FETCH_FILE_ERROR,
    FETCH_NO_COMMAND_ERROR,
    FETCH_WATCH_ERROR,
    FETCH_INVALID_METHOD_ERROR,
    DUMP_INVALID_METHOD_ERROR,
};

enum BUG_COND { BUG_COND_TRIGGERED = 'T', BUG_COND_REACHED = 'R' };

struct select_bug {
    bool enabled;
    char *id;
    enum BUG_COND cond;
    char *out;
    int fd;
    canary_storage_t count;
};

/**
 * Argument parsing infrastructure
 */
struct arg_definition {
    char *name; // string identifier in the list of program arguments
    bool flag;  // if true, the argument does not expect a subsequent parameter
    char *dflt; // the default parameter value (if not present in the arg list)
    char *help;
};

struct arg_item {
    const struct arg_definition *def;
    char *value;
    void *args;
};

enum ARG_NUMS {
    ARG_DUMP = 0,
    ARG_FETCH,
    ARG_SELECT_BUG,
    ARG_SELECT_BUG_COND,
    ARG_SELECT_BUG_OUT,
    ARG_HELP,

    ARG_COUNT
};

const struct arg_definition ARG_LIST[] = {
    {"--dump", false, "raw",
     "The format to use when dumping canary structs:\n"
     "- raw: dumps the raw bytes\n"
     "- row: writes a CSV-style header and data row\n"
     "- human: writes a human-readable output"},
    {"--fetch", false, "file",
     "The source from which to fetch canary data:\n"
     "- file: reads data from FILE\n"
     "- watch: runs COMMAND and collects data"},
    {"--select-bug", false, NULL, "Extract counter for a specific bug"},
    {"--select-bug-cond", false, "T", "The bug condition to select (T/R)"},
    {"--select-bug-out", false, NULL, "Output file for the selected counter"},
    {"--help", true, NULL, "Prints this help message"}};

const char USAGE[] = "monitor [--dump {raw|row|human}] [--fetch {file|watch}]"
                     " [--select-bug BUG_ID] [--select-bug-cond {T|R}]"
                     " [--select-bug-out FILE] FILE|COMMAND";

// TODO replace this by calls to getopt()

struct arg_item *parse_args(int *argc, char ***argv)
{
    struct arg_node {
        struct arg_item item;
        struct arg_node *next;
    };
    int i, count = 0;
    struct arg_node *cur, *head = NULL;
    for (i = 1; i < *argc; ++i) {
        char *keyword = (*argv)[i];
        int j;
        for (j = 0; j < sizeof(ARG_LIST) / sizeof(*ARG_LIST); ++j) {
            if (strcmp(keyword, ARG_LIST[j].name)) {
                continue;
            }
            cur = calloc(1, sizeof(struct arg_node));
            cur->item.def = &ARG_LIST[j];
            if (!cur->item.def->flag) {
                cur->item.value = (*argv)[++i];
            }
            break;
        }
        if (j == sizeof(ARG_LIST) / sizeof(*ARG_LIST)) {
            break; // this assumes that either FILE or COMMAND will follow
        } else {
            cur->next = head;
            head = cur;
            ++count;
        }
    }
    // Decrement `i` since we start with 1
    // --i;
    *argc -= i;
    *argv += i;

    struct arg_item *retarr = malloc(count * sizeof(struct arg_item) + 1);
    for (i = count - 1; i >= 0; --i) {
        memcpy(&retarr[i], &head->item, sizeof(struct arg_item));
        cur = head->next;
        free(head);
        head = cur;
    }
    retarr[count].def = NULL;
    return retarr;
}

void print_help()
{
    puts(USAGE);
    puts("");
    for (int i = 0; i < sizeof(ARG_LIST) / sizeof(*ARG_LIST); ++i) {
        puts(ARG_LIST[i].name);
        puts("");
        puts(ARG_LIST[i].help);
        puts("");
    }
}

static inline void select_bug_check_count(void *arg, pcanary_t canary)
{
    struct select_bug *select_bug = (struct select_bug *)arg;
    if (select_bug && select_bug->enabled && strcmp(canary->name, select_bug->id) == 0)
        select_bug->count =
            select_bug->cond == BUG_COND_TRIGGERED ? canary->triggered : canary->reached;
}

void *dump_one_raw(pcanary_t canary, void *arg)
{
    select_bug_check_count(arg, canary);
    fwrite(canary, sizeof(*canary), 1, stdout);
    return NULL;
}

void dump_raw(const data_t *data, struct select_bug *select_bug)
{
    stor_forall((pcanary_t)(*data), dump_one_raw, select_bug, NULL, -1);
}

struct dump_row_arg {
    bool begin;
    struct select_bug *select_bug;
};

void *dump_one_row_header(pcanary_t canary, void *arg)
{
    struct dump_row_arg *arg_ = (struct dump_row_arg *)arg;
    select_bug_check_count(arg_->select_bug, canary);
    if (!arg_->begin) {
        putc(',', stdout);
    }
    fprintf(stdout, "%1$s_R,%1$s_T", canary->name);
    arg_->begin = false;
    return NULL;
}

void *dump_one_row_data(pcanary_t canary, void *arg)
{
    bool *begin = (bool *)arg;
    if (!*begin) {
        putc(',', stdout);
    }
    fprintf(stdout, "%llu,%llu", canary->reached, canary->triggered);
    *begin = false;
    return NULL;
}

void dump_row(const data_t *data, struct select_bug *select_bug)
{
    struct dump_row_arg arg = {true, select_bug};
    stor_forall((pcanary_t)(*data), dump_one_row_header, &arg, NULL, -1);
    putc('\n', stdout);

    arg.begin = true;
    stor_forall((pcanary_t)(*data), dump_one_row_data, &arg.begin, NULL, -1);
    putc('\n', stdout);
}

void *dump_one_human(pcanary_t canary, void *arg)
{
    select_bug_check_count(arg, canary);
    printf("%s reached %llu triggered %llu\n", canary->name, canary->reached, canary->triggered);
    return NULL;
}

void dump_human(const data_t *data, struct select_bug *select_bug)
{
    stor_forall((pcanary_t)(*data), dump_one_human, select_bug, NULL, -1);
}

bool fetch_file(data_t *data, const char *fname)
{
    bool success = true;
    pstored_data_t data_ptr;
    int fd = open(fname, O_RDWR);
    if (fd == -1) {
        fd = open(fname, O_CREAT | O_RDWR, 0666);
        if (fd < 0) {
            fprintf(stderr, "Error: Failed to open %s\n", fname);
            success = false;
            goto exit;
        }
        if (ftruncate(fd, FILESIZE) != 0) {
            fputs("Error: Failed to truncate file", stderr);
            success = false;
            goto exit;
        }

        data_ptr = mmap(0, FILESIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        memset(data_ptr, 0, FILESIZE);
    } else {
        data_ptr = mmap(0, FILESIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    }

    /* Since the file may be updated by a live producer, we follow protocol*/
    if (!data_ptr->consumed) {
        memcpy(*data, data_ptr->consumer_buffer, sizeof(data_t));
        __sync_synchronize();
        data_ptr->consumed = true;
    } else {
        success = false;
        goto exit;
    }
exit:
    munmap(data_ptr, FILESIZE);
    close(fd);
    return success;
}

bool fetch_watch(data_t *data, int *status, int argc, char **argv)
{
    bool success = true;
    char fname[PATH_MAX];
    getcwd(fname, sizeof(fname));
    strcat(strcat(fname, "/"), "monitor_XXXXXX");
    int fd = mkstemp(fname);
    if (fd < 0) {
        fprintf(stderr, "Error: Failed to create %s\n", fname);
        success = false;
        goto exit;
    }
    if (ftruncate(fd, FILESIZE) != 0) {
        fputs("Error: Failed to truncate file", stderr);
        success = false;
        goto exit;
    }

    if (fork() == 0) {
        dup2(open("/dev/null", O_WRONLY), STDOUT_FILENO);
        dup2(open("/dev/null", O_WRONLY), STDERR_FILENO);
        char envname[] = "MAGMA_STORAGE";
        int envsz = strlen(envname) + 1 + strlen(fname) + 1;
        char *envvar = malloc(envsz);
        snprintf(envvar, envsz, "%s=%s", envname, fname);
        putenv(envvar);
        exit(execve(argv[0], argv, environ));
    }
    wait(status);

    pstored_data_t data_ptr;
    data_ptr = mmap(0, FILESIZE, PROT_READ, MAP_SHARED, fd, 0);

    /* Since the producer is dead, we can fetch its buffer directly */
    memcpy(*data, data_ptr->producer_buffer, sizeof(data_t));

exit:
    unlink(fname);
    return success;
}

int main(int argc, char **argv)
{
    int err = 0;
    struct arg_item *args = parse_args(&argc, &argv), *tmp;
    for (tmp = args; tmp->def != NULL; ++tmp) {
        if (tmp->def == &ARG_LIST[ARG_HELP]) {
            print_help();
            goto exit;
        }
    }

    struct select_bug select_bug = {
        0,
        .fd = -1,
        .id = ARG_LIST[ARG_SELECT_BUG].dflt,
        .out = ARG_LIST[ARG_SELECT_BUG_OUT].dflt,
        .cond = ARG_LIST[ARG_SELECT_BUG_COND].dflt[0],
    };

    struct arg_item *dump_itm = NULL, *fetch_itm = NULL;
    for (tmp = args; tmp->def != NULL; ++tmp) {
        if (tmp->def == &ARG_LIST[ARG_DUMP]) {
            dump_itm = tmp;
        } else if (tmp->def == &ARG_LIST[ARG_FETCH]) {
            fetch_itm = tmp;
        } else if (tmp->def == &ARG_LIST[ARG_SELECT_BUG]) {
            select_bug.enabled = true;
            select_bug.id = tmp->value;
        } else if (tmp->def == &ARG_LIST[ARG_SELECT_BUG_OUT]) {
            select_bug.enabled = true;
            select_bug.out = tmp->value;
        } else if (tmp->def == &ARG_LIST[ARG_SELECT_BUG_COND]) {
            select_bug.enabled = true;
            if (strlen(tmp->value) > 0 &&
                (tmp->value[0] == BUG_COND_TRIGGERED || tmp->value[0] == BUG_COND_REACHED)) {
                select_bug.cond = tmp->value[0];
            } else {
                fputs("Error: Invalid select bug condition", stderr);
                err = SELECT_INVALID_ARGS_ERROR;
                goto exit;
            }
        }
    }

    if (select_bug.enabled) {
        if (select_bug.id == NULL || strlen(select_bug.id) == 0) {
            fputs("Error: No select bug ID specified", stderr);
            err = SELECT_INVALID_ARGS_ERROR;
        }
        if (select_bug.out == NULL || strlen(select_bug.out) == 0) {
            fputs("Error: No select bug output file specified", stderr);
            err = SELECT_INVALID_ARGS_ERROR;
        }
        if (err != 0)
            goto exit;
    }

    data_t data;
    if (fetch_itm == NULL || strcmp(fetch_itm->value, fetch_itm->def->dflt) == 0) {
        const char *fname = NAME;
        if (argc > 0) {
            fname = argv[0];
        }
        if (!fetch_file(&data, fname)) {
            err = FETCH_FILE_ERROR;
            goto exit;
        }
    } else if (strcmp(fetch_itm->value, "watch") == 0) {
        if (argc == 0) {
            fputs("Error: No command specified", stderr);
            err = FETCH_NO_COMMAND_ERROR;
            goto exit;
        }
        int status;
        if (!fetch_watch(&data, &status, argc, argv)) {
            err = FETCH_WATCH_ERROR;
            goto exit;
        }
        if (WIFEXITED(status)) {
            err = WEXITSTATUS(status);
        }
    } else {
        fputs("Error: Invalid fetch method", stderr);
        err = FETCH_INVALID_METHOD_ERROR;
        goto exit;
    }

    if (dump_itm == NULL || strcmp(dump_itm->value, dump_itm->def->dflt) == 0) {
        dump_raw(&data, &select_bug);
    } else if (strcmp(dump_itm->value, "row") == 0) {
        dump_row(&data, &select_bug);
    } else if (strcmp(dump_itm->value, "human") == 0) {
        dump_human(&data, &select_bug);
    } else {
        fputs("Error: Invalid dump method", stderr);
        err = DUMP_INVALID_METHOD_ERROR;
        goto exit;
    }

    if (select_bug.enabled) {
        select_bug.fd = open(select_bug.out, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (select_bug.fd < 0) {
            fprintf(stderr, "Error: Failed to open %s\n", select_bug.out);
            err = SELECT_FILE_ERROR;
            goto exit;
        }
        char count_str[32];
        snprintf(count_str, sizeof(count_str), "%llu", select_bug.count);
        if (write(select_bug.fd, count_str, strlen(count_str)) < 0) {
            fprintf(stderr, "Error: Failed to write to %s\n", select_bug.out);
            err = SELECT_FILE_ERROR;
            goto exit;
        }
    }

exit:
    if (select_bug.fd != -1)
        close(select_bug.fd);
    free(args);
    return err;
}

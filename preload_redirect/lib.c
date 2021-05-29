// Modified from: https://github.com/lilydjwg/openredir
// License SPDX-ID: BSD-2-Clause
#include<stdarg.h>
#include<dlfcn.h>
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<limits.h>
#include<unistd.h>
#include<dirent.h>
#include<sys/stat.h>

// In format `from_path1:to_path1:from_path2:to_path2:`
#define REDIRECT_PATHS_ENV "PRELOAD_REDIRECT_PATHS"
#define DEBUG_ENV "PRELOAD_REDIRECT_DEBUG"
#define BANNER "xdgify-overlay: "

#define die(fmt, ...) \
  do { \
    fprintf(stderr, BANNER fmt "\n" ,##__VA_ARGS__); \
    fflush(stderr); \
    exit(1); \
  } while (0)

#define debug(fmt, ...) \
  do { \
    if (enable_debug) { \
      fprintf(stderr, BANNER fmt "\n" ,##__VA_ARGS__); \
      fflush(stderr); \
    } \
  } while (0)

static void lib_init();

static char *redirect_paths = NULL;
static int enable_debug = 0;

static int lib_initialized = 0;
static int (*orig_access)(const char*, int) = 0;
static int (*orig_statx)(int, const char *, int, unsigned, void *) = 0;
static int (*orig_open)(const char*, int, mode_t) = 0;
static int (*orig_open64)(const char*, int, mode_t) = 0;
static int (*orig_creat)(const char*, mode_t) = 0;
static int (*orig_creat64)(const char*, mode_t) = 0;
static ssize_t (*orig_readlink)(const char*, char*, size_t) = 0;
static int (*orig___open_2)(const char*, int) = 0;
static int (*orig___open64_2)(const char*, int) = 0;
static int (*orig___xstat)(int, const char*, struct stat*) = 0;
static int (*orig___xstat64)(int, const char*, struct stat*) = 0;
static int (*orig___lxstat)(int, const char*, struct stat*) = 0;
static int (*orig___lxstat64)(int, const char*, struct stat*) = 0;
static int (*orig_execve)(const char*, char *const*, char *const*) = 0;
static DIR *(*orig_opendir)(const char *path) = 0;
static int (*orig_mkdir)(const char *path, mode_t mode) = 0;
static char *(*orig_realpath)(const char *restrict path, char *restrict resolved_path) = 0;

static char* search_redirect(const char* path) {
  if (redirect_paths == NULL)
    return NULL;

  char *from = redirect_paths;
  while (*from) {
    char *delim = strchr(from, ':');
    if (delim == NULL)
      die("Invalid redirect paths without delimiter");
    char *end = strchr(delim + 2, ':');
    if (end == NULL)
      die("Invalid redirect paths without terminator");

    size_t from_len = delim - from;
    size_t to_len = end - (delim + 1);
    if (strncmp(path, from, from_len) == 0 &&
        (path[from_len] == '\0' || path[from_len] == '/')) {
      size_t tail_len = strlen(path + from_len);
      char *ret = malloc(to_len + tail_len + 1);
      memcpy(ret, delim + 1, to_len);
      memcpy(ret + to_len, path + from_len, tail_len);
      ret[to_len + tail_len] = 0;
      debug("Redirected: %s -> %s", path, ret);
      return ret;
    }

    from = end + 1;
  }

  return NULL;
}

#define maybe_redirect(expr) \
  lib_init(); \
  const char *path2 = search_redirect(path); \
  if (path2) { \
    ret = expr; \
    free((void *)path2); \
    return ret; \
  } else { \
    path2 = path; \
    return expr; \
  }

int access(const char *path, int mode) {
  int ret;
  maybe_redirect(orig_access(path2, mode));
}

int statx(int dirfd, const char *path, int flags, unsigned mask, void *statxbuf) {
  int ret;
  maybe_redirect(orig_statx(dirfd, path2, flags, mask, statxbuf));
}

int open(const char* path, int flags, mode_t mode) {
  int ret;
  maybe_redirect(orig_open(path2, flags, mode));
}

int open64(const char* path, int flags, mode_t mode) {
  int ret;
  maybe_redirect(orig_open64(path2, flags, mode));
}

int creat(const char* path, mode_t mode) {
  int ret;
  maybe_redirect(orig_creat(path2, mode));
}

int creat64(const char* path, mode_t mode) {
  int ret;
  maybe_redirect(orig_creat64(path2, mode));
}

ssize_t readlink(const char* path, char* buf, size_t bufsiz) {
  ssize_t ret;
  maybe_redirect(orig_readlink(path2, buf, bufsiz));
}

int __open_2(const char* path, int flags) {
  int ret;
  maybe_redirect(orig___open_2(path2, flags));
}

int __open64_2(const char* path, int flags) {
  int ret;
  maybe_redirect(orig___open64_2(path2, flags));
}

int __xstat(int vers, const char* path, struct stat* buf) {
  int ret;
  maybe_redirect(orig___xstat(vers, path2, buf));
}

int __xstat64(int vers, const char* path, struct stat* buf) {
  int ret;
  maybe_redirect(orig___xstat64(vers, path2, buf));
}

int __lxstat(int vers, const char* path, struct stat* buf) {
  int ret;
  maybe_redirect(orig___lxstat(vers, path2, buf));
}

int __lxstat64(int vers, const char* path, struct stat* buf) {
  int ret;
  maybe_redirect(orig___lxstat64(vers, path2, buf));
}

int execve(const char* path, char *const* argv, char *const* envp) {
  int ret;
  maybe_redirect(orig_execve(path2, argv, envp));
}

DIR *opendir(const char *path) {
  DIR *ret;
  maybe_redirect(orig_opendir(path2));
}

int mkdir (const char *path, mode_t mode) {
  int ret;
  maybe_redirect(orig_mkdir(path2, mode));
}

char *realpath(const char *restrict path, char *restrict resolved_path) {
  char *ret;
  maybe_redirect(orig_realpath(path2, resolved_path));
}

static void lib_init() {
  void *libhdl;
  char *dlerr;

  if (lib_initialized) return;

  char *debug_env = getenv(DEBUG_ENV);
  if (debug_env && strcmp(debug_env, "1") == 0)
    enable_debug = 1;

  redirect_paths = getenv(REDIRECT_PATHS_ENV);
  if (redirect_paths)
    debug("Init: %s", redirect_paths);
  else
    debug("Init: no redirect paths loaded");

  if (!(libhdl=dlopen("@libc@", RTLD_LAZY)))
    die("Failed to open libc: %s", dlerror());

#define hook(name) \
  orig_##name = dlsym(libhdl, #name); \
  if ((dlerr = dlerror()) != NULL) \
    die("Failed to patch `" #name "` library call: %s", dlerr);

  hook(access);
  hook(statx);
  hook(open);
  hook(open64);
  hook(creat);
  hook(creat64);
  hook(readlink);
  hook(__open_2);
  hook(__open64_2);
  hook(__xstat);
  hook(__xstat64);
  hook(__lxstat);
  hook(__lxstat64);
  hook(execve);
  hook(opendir);
  hook(mkdir);
  hook(realpath);

  lib_initialized = 1;
}

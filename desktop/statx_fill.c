// gVisor answers statx() on /proc and /sys without STATX_SIZE|STATX_BLOCKS in stx_mask. glib >= 2.80 treats a
// mask short of what it asked for as ERANGE, so every GTK file chooser dies listing "/" with "Numerical result
// out of range". Real Linux always fills the basic stats, so this tops the mask up from a plain stat.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <sys/stat.h>

int statx(int dirfd, const char *path, int flags, unsigned int mask, struct statx *out) {
  static int (*real)(int, const char *, int, unsigned int, struct statx *);
  if (!real) real = dlsym(RTLD_NEXT, "statx");
  int r = real(dirfd, path, flags, mask, out);
  unsigned int missing = mask & ~out->stx_mask & (STATX_SIZE | STATX_BLOCKS);
  if (r != 0 || !missing) return r;
  struct stat st;
  if (fstatat(dirfd, path, &st, flags & (AT_SYMLINK_NOFOLLOW | AT_EMPTY_PATH)) == 0) {
    out->stx_size = st.st_size;
    out->stx_blocks = st.st_blocks;
    out->stx_mask |= missing;
  }
  return r;
}

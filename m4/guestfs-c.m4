# libguestfs
# Copyright (C) 2009-2020 Red Hat Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

dnl The C compiler environment.
dnl Define the host CPU architecture (defines 'host_cpu')
AC_CANONICAL_HOST

dnl Check for basic C environment.
AC_PROG_CC_STDC
AC_PROG_INSTALL
AC_PROG_CPP

AC_ARG_ENABLE([werror],
    [AS_HELP_STRING([--enable-werror],
                    [turn GCC warnings into errors (for developers)])],
    [case $enableval in
     yes|no) ;;
     *)      AC_MSG_ERROR([bad value $enableval for werror option]) ;;
     esac
     gl_gcc_werror=$enableval],
    [gl_gcc_werror=no]
)

if test "$gl_gcc_werror" = yes; then
    gl_WARN_ADD([-Werror], [WERROR_CFLAGS])
    AC_SUBST([WERROR_CFLAGS])
fi

dnl This, $nw, is the list of warnings we disable.
nw=
nw="$nw -Waggregate-return"          # anachronistic
nw="$nw -Wundef"                     # Warns on '#if GNULIB_FOO' etc in gnulib
nw="$nw -Wtraditional"               # Warns on #elif which we use often
nw="$nw -Wsystem-headers"            # Don't let system headers trigger warnings
nw="$nw -Wpadded"                    # Our structs are not padded
nw="$nw -Wvla"                       # Allow variable length arrays.
nw="$nw -Wvla-larger-than=4031"
nw="$nw -Winline"                    # inline functions in Python binding
nw="$nw -Wshadow"                    # Not useful, as it applies to global vars
nw="$nw -Wunsafe-loop-optimizations" # just a warning that an optimization
                                     # was not possible, safe to ignore
nw="$nw -Wstack-protector"           # Useless warning when stack protector
                                     # cannot being used in a function.
nw="$nw -Wcast-align"                # Useless warning on arm >= 7, intel
nw="$nw -Wabi"                       # Broken in GCC 8.1.
dnl things I might fix soon:
nw="$nw -Wpacked"                    # Allow attribute((packed)) on structs
nw="$nw -Wlong-long"                 # Allow long long since it's required
                                     # by Python, Ruby and xstrtoll.
nw="$nw -Wsuggest-attribute=pure"    # Don't suggest pure functions.
nw="$nw -Wsuggest-attribute=const"   # Don't suggest const functions.
nw="$nw -Wsuggest-attribute=malloc"  # Don't suggest malloc functions.
nw="$nw -Wunsuffixed-float-constants" # Don't care about these.
nw="$nw -Wswitch-default"            # This warning is actively dangerous.
nw="$nw -Woverlength-strings"        # Who cares about stupid ISO C99 limit.

gl_MANYWARN_ALL_GCC([ws])
gl_MANYWARN_COMPLEMENT([ws], [$ws], [$nw])
for w in $ws; do
    gl_WARN_ADD([$w])
done

dnl Normally we disable warnings in $nw above.  However $nw only
dnl filters out exact matching warning strings from a list inside
dnl gnulib (see m4/manywarnings.m4).  So we need to explicitly list a
dnl few disabled warnings below.

dnl Unused parameters are not a bug.
gl_WARN_ADD([-Wno-unused-parameter])

dnl Missing field initializers is not a bug in C.
gl_WARN_ADD([-Wno-missing-field-initializers])

dnl Display the name of the warning option with the warning.
gl_WARN_ADD([-fdiagnostics-show-option])

dnl Now some warnings we want to enable and/or customize ...

dnl Warn about large stack frames.  This does not include alloca and
dnl variable length arrays.  Coverity warns about 10000 byte frames.
gl_WARN_ADD([-Wframe-larger-than=6000])

dnl Warn about large stack frames, including estimates for alloca
dnl and variable length arrays.
gl_WARN_ADD([-Wstack-usage=10000])

dnl Warn about implicit fallthrough in case statements, but suppress
dnl the warning if /*FALLTHROUGH*/ comment is used.
gl_WARN_ADD([-Wimplicit-fallthrough=4])

dnl GCC level 2 gives incorrect warnings, so use level 1.
gl_WARN_ADD([-Wformat-truncation=1])

dnl GCC 9 at level 2 gives apparently bogus errors when %.*s is used.
gl_WARN_ADD([-Wformat-overflow=1])

AC_SUBST([WARN_CFLAGS])

NO_SNV_CFLAGS=
gl_COMPILER_OPTION_IF([-Wno-shift-negative-value],[
    NO_SNV_CFLAGS="-Wno-shift-negative-value"
])
AC_SUBST([NO_SNV_CFLAGS])

NO_UM_CFLAGS=
gl_COMPILER_OPTION_IF([-Wno-unused-macros],[
    NO_UM_CFLAGS="-Wno-unused-macros"
])
AC_SUBST([NO_UM_CFLAGS])

AC_DEFINE([lint], [1], [Define to 1 if the compiler is checking for lint.])
AC_DEFINE([GNULIB_PORTCHECK], [1], [Enable some gnulib portability checks.])

AC_C_PROTOTYPES
test "x$U" != "x" && AC_MSG_ERROR([Compiler not ANSI compliant])

AM_PROG_CC_C_O

# Provide a global place to set CFLAGS.  (Note that setting AM_CFLAGS
# is no use because it doesn't override target_CFLAGS).
#---
# Kill -fstrict-overflow which is a license for the C compiler to make
# dubious and often unsafe optimizations, in a time-wasting attempt to
# deal with CPU architectures that do not exist.
CFLAGS="$CFLAGS -fno-strict-overflow -Wno-strict-overflow"

dnl Work out how to specify the linker script to the linker.
VERSION_SCRIPT_FLAGS=-Wl,--version-script=
`/usr/bin/ld --help 2>&1 | grep -- --version-script >/dev/null` || \
    VERSION_SCRIPT_FLAGS="-Wl,-M -Wl,"
AC_SUBST(VERSION_SCRIPT_FLAGS)

dnl Use -fvisibility=hidden by default in the library.
dnl http://gcc.gnu.org/wiki/Visibility
AS_IF([test -n "$GCC"],
    [AC_SUBST([GCC_VISIBILITY_HIDDEN], [-fvisibility=hidden])],
    [AC_SUBST([GCC_VISIBILITY_HIDDEN], [:])])

dnl Check support for 64 bit file offsets.
AC_SYS_LARGEFILE

dnl Check sizeof long.
AC_CHECK_SIZEOF([long])

dnl Check if __attribute__((cleanup(...))) works.
dnl Set -Werror, otherwise gcc will only emit a warning for attributes
dnl that it doesn't understand.
acx_nbdkit_save_CFLAGS="${CFLAGS}"
CFLAGS="${CFLAGS} -Werror"
AC_MSG_CHECKING([if __attribute__((cleanup(...))) works with this compiler])
AC_COMPILE_IFELSE([
AC_LANG_SOURCE([[
#include <stdio.h>
#include <stdlib.h>

void
freep (void *ptr)
{
  exit (EXIT_SUCCESS);
}

void
test (void)
{
  __attribute__((cleanup(freep))) char *ptr = malloc (100);
}

int
main (int argc, char *argv[])
{
  test ();
  exit (EXIT_FAILURE);
}
]])
    ],[
    AC_MSG_RESULT([yes])
    AC_DEFINE([HAVE_ATTRIBUTE_CLEANUP],[1],[Define to 1 if '__attribute__((cleanup(...)))' works with this compiler.])
    ],[
    AC_MSG_WARN(
['__attribute__((cleanup(...)))' does not work.

You may not be using a sufficiently recent version of GCC or CLANG, or
you may be using a C compiler which does not support this attribute,
or the configure test may be wrong.

The code will still compile, but is likely to leak memory and other
resources when it runs.])])
dnl restore CFLAGS
CFLAGS="${acx_nbdkit_save_CFLAGS}"

dnl Should we run the gnulib tests?
AC_MSG_CHECKING([if we should run the GNUlib tests])
AC_ARG_ENABLE([gnulib-tests],
    [AS_HELP_STRING([--disable-gnulib-tests],
        [disable running GNU Portability library tests @<:@default=yes@:>@])],
        [ENABLE_GNULIB_TESTS="$enableval"],
        [ENABLE_GNULIB_TESTS=yes])
AM_CONDITIONAL([ENABLE_GNULIB_TESTS],[test "x$ENABLE_GNULIB_TESTS" = "xyes"])
AC_MSG_RESULT([$ENABLE_GNULIB_TESTS])

# Makefile for bcftools, utilities for Variant Call Format VCF/BCF files.
#
#   Copyright (C) 2012-2017 Genome Research Ltd.
#
#   Author: Petr Danecek <pd3@sanger.ac.uk>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

CC       = gcc
CPPFLAGS =
CFLAGS   = -g -Wall -Wc++-compat -O2
LDFLAGS  =
LIBS     =

DYNAMIC_FLAGS = -rdynamic
PLUGINS_ENABLED = yes
PLUGIN_EXT = .so
OBJS     = main.o vcfindex.o tabix.o \
           vcfstats.o vcfisec.o vcfmerge.o vcfquery.o vcffilter.o filter.o vcfsom.o \
           vcfnorm.o vcfgtcheck.o vcfview.o vcfannotate.o vcfroh.o vcfconcat.o \
           vcfcall.o mcall.o vcmp.o gvcf.o reheader.o convert.o vcfconvert.o tsv2vcf.o \
           vcfcnv.o HMM.o vcfplugin.o consensus.o ploidy.o bin.o hclust.o version.o \
           regidx.o smpl_ilist.o csq.o vcfbuf.o \
           mpileup.o bam2bcf.o bam2bcf_indel.o bam_sample.o \
           vcfsort.o cols.o \
           ccall.o em.o prob1.o kmin.o # the original samtools calling

prefix      = /usr/local
exec_prefix = $(prefix)
bindir      = $(exec_prefix)/bin
libdir      = $(exec_prefix)/lib
libexecdir  = $(exec_prefix)/libexec
mandir      = $(prefix)/share/man
man1dir     = $(mandir)/man1
# Installation location for $(PLUGINS)
plugindir   = $(libexecdir)/bcftools
pluginpath  = $(plugindir)
# Installation location for $(MISC_PROGRAMS) and $(MISC_SCRIPTS)
misc_bindir = $(bindir)

MKDIR_P = mkdir -p
INSTALL = install -p
INSTALL_DATA    = $(INSTALL) -m 644
INSTALL_DIR     = $(MKDIR_P) -m 755
INSTALL_MAN     = $(INSTALL_DATA)
INSTALL_PROGRAM = $(INSTALL)
INSTALL_SCRIPT  = $(INSTALL_PROGRAM)

PROGRAMS = bcftools
MISC_SCRIPTS = \
    misc/color-chrs.pl \
    misc/guess-ploidy.py \
    misc/plot-vcfstats \
    misc/plot-roh.py \
    misc/run-roh.pl \
    misc/vcfutils.pl
TEST_PROGRAMS = test/test-rbuf test/test-regidx
PLUGINC = $(foreach dir, plugins, $(wildcard $(dir)/*.c))
PLUGINS = $(PLUGINC:.c=.so)
PLUGINM = $(PLUGINC:.c=.mk)

all: $(PROGRAMS) $(TEST_PROGRAMS) $(PLUGINS)

ALL_CPPFLAGS = -I. $(HTSLIB_CPPFLAGS) $(CPPFLAGS)
ALL_LDFLAGS  = $(HTSLIB_LDFLAGS) $(LDFLAGS)
ALL_LIBS     = -lz $(LIBS)

EXTRA_CPPFLAGS = -DPLUGINPATH=\"$(pluginpath)\"
GSL_LIBS       =

# The polysomy command is not compiled by default because it brings dependency
# on libgsl. The command can be compiled wth `make USE_GPL=1`. See the INSTALL
# and LICENSE documents to understand license implications.
ifdef USE_GPL
    main.o : EXTRA_CPPFLAGS += -DUSE_GPL
    OBJS += polysomy.o peakfit.o
    GSL_LIBS ?= -lgsl -lcblas
endif

# Usually config.mk and config.h are generated by running configure
# or config.status, but if those aren't used create defaults here.
config.mk:
	@sed -e '/^prefix/,/^PLUGIN_EXT/d;s/@Hsource@//;s/@Hinstall@/#/;s#@HTSDIR@#../htslib#g;s/@HTSLIB_CPPFLAGS@/-I$$(HTSDIR)/g;' config.mk.in > $@

config.h:
	echo '/* Basic config.h generated by Makefile */' > $@
ifneq "$(PLUGINS_ENABLED)" "no"
	echo '#define ENABLE_BCF_PLUGINS 1' >> $@
	echo '#define PLUGIN_EXT ".so"' >> $@
endif


PACKAGE_VERSION = 1.9

# If building from a Git repository, replace $(PACKAGE_VERSION) with the Git
# description of the working tree: either a release tag with the same value
# as $(PACKAGE_VERSION) above, or an exact description likely based on a tag.
# $(shell), :=, etc are GNU Make-specific.  If you don't have GNU Make,
# comment out this conditional.
ifneq "$(wildcard .git)" ""
PACKAGE_VERSION := $(shell git describe --always --dirty)
DOC_VERSION :=  $(shell git describe --always)+
DOC_DATE := $(shell date +'%Y-%m-%d %R %Z')

# Force version.h to be remade if $(PACKAGE_VERSION) has changed.
version.h: $(if $(wildcard version.h),$(if $(findstring "$(PACKAGE_VERSION)",$(shell cat version.h)),,force))
endif

# If you don't have GNU Make but are building from a Git repository, you may
# wish to replace this with a rule that always rebuilds version.h:
# version.h: force
#	echo '#define BCFTOOLS_VERSION "`git describe --always --dirty`"' > $@
version.h:
	echo '#define BCFTOOLS_VERSION "$(PACKAGE_VERSION)"' > $@

print-version:
	@echo $(PACKAGE_VERSION)

.SUFFIXES: .c .o

.c.o:
	$(CC) $(CFLAGS) $(ALL_CPPFLAGS) $(EXTRA_CPPFLAGS) -c -o $@ $<


bcftools: $(OBJS) $(HTSLIB)
	$(CC) $(DYNAMIC_FLAGS) -pthread $(ALL_LDFLAGS) -o $@ $(OBJS) $(HTSLIB_LIB) -lm $(ALL_LIBS) $(GSL_LIBS) $(PERL_LIBS)

# Plugin rules
ifneq "$(PLUGINS_ENABLED)" "no"
PLUGINC = $(foreach dir, plugins, $(wildcard $(dir)/*.c))
PLUGINS = $(PLUGINC:.c=$(PLUGIN_EXT))
PLUGINM = $(PLUGINC:.c=.mk)

ifneq "$(origin PLATFORM)" "file"
PLATFORM := $(shell uname -s)
endif
ifeq "$(PLATFORM)" "Darwin"
$(PLUGINS): | bcftools
PLUGIN_FLAGS = -bundle -bundle_loader bcftools -Wl,-undefined,dynamic_lookup
else
DYNAMIC_FLAGS = -rdynamic
PLUGIN_FLAGS = -fPIC -shared
endif

vcfplugin.o: EXTRA_CPPFLAGS += -DPLUGINPATH='"$(pluginpath)"'

%.so: %.c version.h version.c
	$(CC) $(PLUGIN_FLAGS) $(CFLAGS) $(ALL_CPPFLAGS) $(EXTRA_CPPFLAGS) $(LDFLAGS) -o $@ version.c $< $(LIBS)

-include $(PLUGINM)

test check: test-plugins

else   # PLUGINS_ENABLED

PLUGINC =
PLUGINS =
PLUGINM =

test check: test-no-plugins

endif  # PLUGINS_ENABLED

plugins: $(PLUGINS)
bcftools_h = bcftools.h $(htslib_hts_defs_h) $(htslib_vcf_h)
bin_h = bin.h $(htslib_hts_h)
call_h = call.h $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) vcmp.h
variantkey_h = variantkey.h
convert_h = convert.h $(htslib_vcf_h) $(variantkey_h)
tsv2vcf_h = tsv2vcf.h $(htslib_vcf_h)
filter_h = filter.h $(htslib_vcf_h)
gvcf_h = gvcf.h $(bcftools_h)
khash_str2str_h = khash_str2str.h $(htslib_khash_h)
ploidy_h = ploidy.h regidx.h
prob1_h = prob1.h $(htslib_vcf_h) $(call_h)
smpl_ilist_h = smpl_ilist.h $(htslib_vcf_h)
vcfbuf_h = vcfbuf.h $(htslib_vcf_h)
roh_h = HMM.h $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(htslib_kstring_h) $(htslib_kseq_h) $(bcftools_h)
cnv_h = HMM.h $(htslib_vcf_h) $(htslib_synced_bcf_reader_h)
bam2bcf_h = bam2bcf.h $(htslib_hts_h) $(htslib_vcf_h)
bam_sample_h = bam_sample.h $(htslib_sam_h)

main.o: main.c $(htslib_hts_h) config.h version.h $(bcftools_h)
vcfannotate.o: vcfannotate.c $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(htslib_kseq_h) $(htslib_khash_str2int_h) $(bcftools_h) vcmp.h $(filter_h) $(convert_h) $(smpl_ilist_h) $(htslib_khash_h)
vcfplugin.o: vcfplugin.c config.h $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(htslib_kseq_h) $(htslib_khash_str2int_h) $(bcftools_h) vcmp.h $(filter_h)
vcfcall.o: vcfcall.c $(htslib_vcf_h) $(htslib_kfunc_h) $(htslib_synced_bcf_reader_h) $(htslib_khash_str2int_h) $(bcftools_h) $(call_h) $(prob1_h) $(ploidy_h) $(gvcf_h)
vcfconcat.o: vcfconcat.c $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(htslib_kseq_h) $(htslib_bgzf_h) $(htslib_tbx_h) $(bcftools_h)
vcfconvert.o: vcfconvert.c $(htslib_faidx_h) $(htslib_vcf_h) $(htslib_bgzf_h) $(htslib_synced_bcf_reader_h) $(htslib_vcfutils_h) $(htslib_kseq_h) $(bcftools_h) $(filter_h) $(convert_h) $(tsv2vcf_h)
vcffilter.o: vcffilter.c $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(htslib_vcfutils_h) $(bcftools_h) $(filter_h) rbuf.h
vcfgtcheck.o: vcfgtcheck.c $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(htslib_vcfutils_h) $(bcftools_h) hclust.h
vcfindex.o: vcfindex.c $(htslib_vcf_h) $(htslib_tbx_h) $(htslib_kstring_h) $(htslib_bgzf_h) $(bcftools_h)
vcfisec.o: vcfisec.c $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(htslib_vcfutils_h) $(bcftools_h) $(filter_h)
vcfmerge.o: vcfmerge.c $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(htslib_vcfutils_h) $(htslib_faidx_h) regidx.h $(bcftools_h) vcmp.h $(htslib_khash_h)
vcfnorm.o: vcfnorm.c $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(htslib_faidx_h) $(htslib_khash_str2int_h) $(bcftools_h) rbuf.h
vcfquery.o: vcfquery.c $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(htslib_khash_str2int_h) $(htslib_vcfutils_h) $(bcftools_h) $(filter_h) $(convert_h)
vcfroh.o: vcfroh.c $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(htslib_kstring_h) $(htslib_kseq_h) $(htslib_bgzf_h) $(bcftools_h) HMM.h $(smpl_ilist_h) $(filter_h) $(roh_h)
vcfcnv.o: vcfcnv.c $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(htslib_kstring_h) $(htslib_kfunc_h) $(htslib_khash_str2int_h) $(bcftools_h) HMM.h rbuf.h $(cnv_h)
vcfsom.o: vcfsom.c $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(htslib_vcfutils_h) $(bcftools_h)
vcfsort.o: vcfsort.c $(htslib_vcf_h) $(htslib_kstring_h) kheap.h $(bcftools_h)
vcfstats.o: vcfstats.c $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(htslib_vcfutils_h) $(htslib_faidx_h) $(bcftools_h) $(filter_h) $(bin_h)
vcfview.o: vcfview.c $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(htslib_vcfutils_h) $(bcftools_h) $(filter_h) $(htslib_khash_str2int_h)
reheader.o: reheader.c $(htslib_vcf_h) $(htslib_bgzf_h) $(htslib_tbx_h) $(htslib_kseq_h) $(htslib_thread_pool_h) $(bcftools_h) $(khash_str2str_h)
tabix.o: tabix.c $(htslib_bgzf_h) $(htslib_tbx_h)
ccall.o: ccall.c $(htslib_kfunc_h) $(call_h) kmin.h $(prob1_h)
convert.o: convert.c $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(htslib_vcfutils_h) $(bcftools_h) $(convert_h)
tsv2vcf.o: tsv2vcf.c $(tsv2vcf_h)
em.o: em.c $(htslib_vcf_h) kmin.h $(call_h)
filter.o: filter.c $(htslib_khash_str2int_h) $(htslib_hts_defs_h) $(htslib_vcfutils_h) $(htslib_kfunc_h) config.h $(filter_h) $(bcftools_h)
	$(CC) $(CFLAGS) $(ALL_CPPFLAGS) $(EXTRA_CPPFLAGS) $(PERL_CFLAGS) -c -o $@ $<
gvcf.o: gvcf.c $(gvcf_h) $(bcftools_h)
kmin.o: kmin.c kmin.h
mcall.o: mcall.c $(htslib_kfunc_h) $(call_h)
prob1.o: prob1.c $(prob1_h)
vcmp.o: vcmp.c $(htslib_hts_h) $(htslib_vcf_h) vcmp.h
ploidy.o: ploidy.c regidx.h $(htslib_khash_str2int_h) $(htslib_kseq_h) $(htslib_hts_h) $(bcftools_h) $(ploidy_h)
polysomy.o: polysomy.c $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(bcftools_h) peakfit.h
peakfit.o: peakfit.c peakfit.h $(htslib_hts_h) $(htslib_kstring_h)
bin.o: bin.c $(bcftools_h) $(bin_h)
cols.o: cols.c cols.h
regidx.o: regidx.c $(htslib_hts_h) $(htslib_kstring_h) $(htslib_kseq_h) $(htslib_khash_str2int_h) regidx.h
consensus.o: consensus.c $(htslib_hts_h) $(htslib_vcf_h) $(htslib_kstring_h) $(htslib_synced_bcf_reader_h) $(htslib_kseq_h) $(htslib_bgzf_h) regidx.h $(bcftools_h) rbuf.h $(filter_h)
mpileup.o: mpileup.c $(htslib_sam_h) $(htslib_faidx_h) $(htslib_kstring_h) $(htslib_khash_str2int_h) regidx.h $(bcftools_h) $(bam2bcf_h) $(bam_sample_h) $(gvcf_h) $(call_h)
bam2bcf.o: bam2bcf.c $(htslib_hts_h) $(htslib_sam_h) $(htslib_kstring_h) $(htslib_kfunc_h) $(bam2bcf_h) mw.h
bam2bcf_indel.o: bam2bcf_indel.c $(htslib_hts_h) $(htslib_sam_h) $(htslib_khash_str2int_h) $(bam2bcf_h) $(htslib_ksort_h)
bam_sample.o: bam_sample.c $(htslib_hts_h) $(htslib_kstring_h) $(htslib_khash_str2int_h) $(khash_str2str_h) $(bam_sample_h) $(bcftools_h)
version.o: version.h version.c
hclust.o: hclust.c $(htslib_hts_h) $(htslib_kstring_h) $(bcftools_h) hclust.h
HMM.o: HMM.c $(htslib_hts_h) HMM.h
vcfbuf.o: vcfbuf.c $(htslib_vcf_h) $(htslib_vcfutils_h) $(bcftools_h) $(vcfbuf_h) rbuf.h
smpl_ilist.o: smpl_ilist.c $(bcftools_h) $(smpl_ilist_h)
csq.o: csq.c $(htslib_hts_h) $(htslib_vcf_h) $(htslib_synced_bcf_reader_h) $(htslib_khash_h) $(htslib_khash_str2int_h) $(htslib_kseq_h) $(htslib_faidx_h) $(bcftools_h) $(filter_h) regidx.h kheap.h $(smpl_ilist_h) rbuf.h

# test programs

# For tests that might use it, set $REF_PATH explicitly to use only reference
# areas within the test suite (or set it to ':' to use no reference areas).
# (regression.sh sets $REF_PATH to a subdirectory itself.)
check test: $(PROGRAMS) $(TEST_PROGRAMS) $(BGZIP) $(TABIX)
	./test/test-rbuf
	./test/test-regidx
	REF_PATH=: ./test/test.pl --exec bgzip=$(BGZIP) --exec tabix=$(TABIX)

test-plugins: $(PROGRAMS) $(TEST_PROGRAMS) $(BGZIP) $(TABIX) plugins
	./test/test-rbuf
	./test/test-regidx
	REF_PATH=: ./test/test.pl --plugins --exec bgzip=$(BGZIP) --exec tabix=$(TABIX)

test/test-rbuf.o: test/test-rbuf.c rbuf.h

test/test-rbuf: test/test-rbuf.o
	$(CC) $(LDFLAGS) -o $@ $^ $(ALL_LIBS)

test/test-regidx.o: test/test-regidx.c $(htslib_kstring_h) regidx.h

test/test-regidx: test/test-regidx.o regidx.o $(htslib_kstring_h) $(HTSLIB)
	$(CC) $(ALL_LDFLAGS) -o $@ $^ $(HTSLIB) -lpthread $(HTSLIB_LIB) $(ALL_LIBS)


# make docs target depends the a2x asciidoc program
doc/bcftools.1: doc/bcftools.txt
	cd doc && a2x -adate="$(DOC_DATE)" -aversion=$(DOC_VERSION) --doctype manpage --format manpage bcftools.txt

doc/bcftools.html: doc/bcftools.txt
	cd doc && a2x -adate="$(DOC_DATE)" -aversion=$(DOC_VERSION) --doctype manpage --format xhtml bcftools.txt

docs: doc/bcftools.1 doc/bcftools.html

# To avoid an install dependency on asciidoc, the make install target
# does not depend on doc/bcftools.1
# bcftools.1 is a generated file from the asciidoc bcftools.txt file.
# Since there is no make dependency, bcftools.1 can be out-of-date and
# make docs can be run to update if asciidoc is available
install: $(PROGRAMS) $(PLUGINS)
	$(INSTALL_DIR) $(DESTDIR)$(bindir) $(DESTDIR)$(man1dir) $(DESTDIR)$(plugindir)
	$(INSTALL_PROGRAM) $(PROGRAMS) $(DESTDIR)$(bindir)
	$(INSTALL_SCRIPT) $(MISC_SCRIPTS) $(DESTDIR)$(misc_bindir)
	$(INSTALL_MAN) doc/bcftools.1 $(DESTDIR)$(man1dir)
	$(INSTALL_PROGRAM) plugins/*.so $(DESTDIR)$(plugindir)

clean: testclean clean-plugins
	-rm -f gmon.out *.o *~ $(PROGRAMS) version.h plugins/*.so plugins/*.P
	-rm -rf *.dSYM plugins/*.dSYM test/*.dSYM

clean-plugins:
	-rm -f plugins/*.so plugins/*.P
	-rm -rf plugins/*.dSYM

testclean:
	-rm -f test/*.o test/*~ $(TEST_PROGRAMS)

distclean: clean
	-rm -f config.cache config.h config.log config.mk config.status
	-rm -rf autom4te.cache
	-rm -f TAGS

clean-all: clean clean-htslib

tags:
	ctags -f TAGS *.[ch] plugins/*.[ch]

force:

.PHONY: all check clean clean-all clean-plugins distclean force install
.PHONY: print-version tags test testclean plugins docs

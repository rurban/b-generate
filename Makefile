all : force_do_it
	/home/josh/perl5.8.3/bin/perl Build
realclean : force_do_it
	/home/josh/perl5.8.3/bin/perl Build realclean
	/home/josh/perl5.8.3/bin/perl -e unlink -e shift Makefile

force_do_it :
	@ true
build : force_do_it
	/home/josh/perl5.8.3/bin/perl Build build
build_config : force_do_it
	/home/josh/perl5.8.3/bin/perl Build build_config
clean : force_do_it
	/home/josh/perl5.8.3/bin/perl Build clean
code : force_do_it
	/home/josh/perl5.8.3/bin/perl Build code
diff : force_do_it
	/home/josh/perl5.8.3/bin/perl Build diff
dist : force_do_it
	/home/josh/perl5.8.3/bin/perl Build dist
distcheck : force_do_it
	/home/josh/perl5.8.3/bin/perl Build distcheck
distclean : force_do_it
	/home/josh/perl5.8.3/bin/perl Build distclean
distdir : force_do_it
	/home/josh/perl5.8.3/bin/perl Build distdir
distmeta : force_do_it
	/home/josh/perl5.8.3/bin/perl Build distmeta
distsign : force_do_it
	/home/josh/perl5.8.3/bin/perl Build distsign
disttest : force_do_it
	/home/josh/perl5.8.3/bin/perl Build disttest
docs : force_do_it
	/home/josh/perl5.8.3/bin/perl Build docs
fakeinstall : force_do_it
	/home/josh/perl5.8.3/bin/perl Build fakeinstall
help : force_do_it
	/home/josh/perl5.8.3/bin/perl Build help
html : force_do_it
	/home/josh/perl5.8.3/bin/perl Build html
install : force_do_it
	/home/josh/perl5.8.3/bin/perl Build install
manifest : force_do_it
	/home/josh/perl5.8.3/bin/perl Build manifest
ppd : force_do_it
	/home/josh/perl5.8.3/bin/perl Build ppd
ppmdist : force_do_it
	/home/josh/perl5.8.3/bin/perl Build ppmdist
skipcheck : force_do_it
	/home/josh/perl5.8.3/bin/perl Build skipcheck
test : force_do_it
	/home/josh/perl5.8.3/bin/perl Build test
testdb : force_do_it
	/home/josh/perl5.8.3/bin/perl Build testdb
versioninstall : force_do_it
	/home/josh/perl5.8.3/bin/perl Build versioninstall

use strict;
use Module::Build;

my %newTweaks;
if ( $] >= 5.008 ) {
    $newTweaks{extra_compiler_flags}
        = '-DPERL_CUSTOM_OPS -DPERL_CUSTOM_OPCODES -g';
}

my $class = Module::Build->subclass(
    class => 'My::Builder',
    code  => q{
sub compile_c {
    my($self, $file) = @_;
    $self->SUPER::compile_c($file);
    return unless $^O eq 'darwin';
    $self->{config}->{lddlflags} =~ s/-flat_namespace/-twolevel_namespace/;
    $self->{config}->{lddlflags} =~ s/-undefined suppress/-undefined error/;
    $self->{config}->{lddlflags} .= " $self->{config}->{archlibexp}/CORE/$self->{config}->{libperl}";
}
     },
);

my $build = $class->new(
    module_name    => 'B::Generate',
    license        => 'perl',
    dynamic_config => 0,
    no_index       => { package => 'B::OP', },
    requires       => {
         perl                => 5.005062,
        'B'                  => '1.09', # see rt29257 re OP_LIST
        'ExtUtils::CBuilder' => 0,
        'Module::Build'      => 0,
    },
    meta_merge     => {
        resources => {
            MailingList => 'mailto:"600 subscribers" <perl5-porters@perl.org>',
            repository  => 'http://github.com/rurban/b-generate',
        }
    },
    %newTweaks,
);
$build->create_build_script;

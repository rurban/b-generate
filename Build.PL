use strict;
use Module::Build;

my %newTweaks;
if ( $] >= 5.008 ) {
    $newTweaks{extra_compiler_flags}
        = '-DPERL_CUSTOM_OPS -DPERL_CUSTOM_OPCODES';
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
        perl                 => '5.5.62',
        'ExtUtils::CBuilder' => 0,
        'Module::Build'      => 0,
    },
    %newTweaks,
);
$build->create_build_script;


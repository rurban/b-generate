use strict;
use Module::Build;

my $class = Module::Build->subclass
    (
     class => 'My::Builder',
     code => q{
sub compile_c {
    my($self, $file) = @_;
    $self->SUPER::compile_c($file);
    return unless($^O eq 'darwin');
    $self->{config}->{lddlflags} =~s/-flat_namespace/-twolevel_namespace/;
    $self->{config}->{lddlflags} =~s/-undefined suppress/-undefined error/;
    $self->{config}->{lddlflags} .= " $self->{config}->{archlibexp}/CORE/$self->{config}->{libperl}";
}
     }
     );
     

my $build = $class->new
    (
     module_name => 'B::Generate',
     license => 'unknown',
     dynamic_config => 0,
     );
$build->create_build_script;



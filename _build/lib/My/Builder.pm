package My::Builder;
use Module::Build;
@ISA = qw(Module::Build);

sub compile_c {
    my($self, $file) = @_;
    $self->SUPER::compile_c($file);
    return unless($^O eq 'darwin');
    $self->{config}->{lddlflags} =~s/-flat_namespace/-twolevel_namespace/;
    $self->{config}->{lddlflags} =~s/-undefined suppress/-undefined error/;
    $self->{config}->{lddlflags} .= " $self->{config}->{archlibexp}/CORE/$self->{config}->{libperl}";
}
     
1;

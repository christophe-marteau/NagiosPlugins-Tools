package NagiosPlugins::Debug;
use warnings;
use strict;
use Carp;

our $VERSION='1.00';
our $Debug=0;

# debug function
# [in] $level :debug level
# [in] $functionName : The function name in which the debug function is call
# [in] @a_String : String array to display
my $debugCurrentDecalage = 0;

sub debug (){
  my ( $level, $functionName, @stringArray ) = @_;

  if ( ( $level == 9 ) && ( join( '', @stringArray ) =~ /^END / ) ) {
    $debugCurrentDecalage --;
  }

  if ( $Debug >= $level ) {
    my $space = '>';
    for ( my $i = 0; $i < $debugCurrentDecalage; $i++ ) {
      $space = '=='.$space;
    }

    my @stringDisplayedArray = split( "\n", join( '', @stringArray ) );
    for ( my $i = 0; $i < scalar( @stringDisplayedArray ); $i++ ) {
      print( '# DEBUG ['.$level.'] '.sprintf( '(%40s)', $functionName ).' :'.
             $space.$stringDisplayedArray[$i]."\n" );
    }
  }

  if ( ( $level == 9 ) && ( join( '', @stringArray ) =~ /^BEGIN / ) ) {
    $debugCurrentDecalage ++;
  }
}

1;

__END__

=head1 NAME

 NagiosPlugins::Debug - Debug function for nagios plugins devel

=head1 SYNOPSIS

 # Global variable for setting debugging level
 $NagiosPlugins::Debug::Debug = <debug level>

 # Function for displaying debug message to stdout
 &NagiosPlugins::Debug::debug( <level>, <function name>, <debug message> );   

=head1 DESCRIPTION

 NagiosPlugins::Debug is a package providing a debug function. It allows 9 levels 
 of debug, and print function name and debug messages below defined global level. 

 Conventionnal use for this function :

   - You must start a function by : 
     &NagiosPlugins::Debug::debug( 9, <function name>', 'BEGIN <function name>' );

   - You must end a function by   : 
     &NagiosPlugins::Debug::debug( 9, <function name>', 'END <function name>' );

   - The function name for an OO function should be : 
     blessed( $self ).'::<function name>

=head1 AUTHORS

 This code is maintained by Christophe Marteau <christophe.marteau(at)univ-tlse3.fr>.

=head1 COPYRIGHT and LICENCE

 Copyright (C) 2014 by Christophe Marteau

 This library is free software; you can redistribute it and/or modify it under the 
 same terms as Perl itself.

=cut

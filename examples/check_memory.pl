#!/usr/bin/perl -w

use strict;
use NagiosPlugins::Core;
my $plugin=NagiosPlugins::Core->new( { 'author'  => 'Christophe Marteau',
                                       'version' => '1.0O',
                                       'description' => 'Check memory Usage',
                                       'usageExample' => ['Typical use is :',   
                                                          '  '.$0.' -w "@0:20,80,80" -c "@0:10,90,90"',
                                                          'Use with perfdata option :',
                                                          '  '.$0.' -w "@0:20,80,80" -c "@0:10,90,90" -f']});

$plugin->addOption( 'file' , {
                              'alias'            => '',
                              'argDescription'   => 'file',
                              'shortDescription' => 'Memory info file',
                              'longDescription'  => 'Where to find /proc memory info file. By default set to "/proc/meminfo"',
                              'regex'            => '.+',
                              'value'            => '/proc/meminfo',
                              'type'             => '=s',
                              'enabled'          => 1
                             } );

$plugin->disableOption('timeout');
$plugin->disableOption('hostname');
$plugin->parseOptions();

# Retrieving memory info
sub getMemoryUsage() {
  my ( $plugin ) = @_;
  &NagiosPlugins::Debug::debug( 9, 'getMemoryUsage', 'BEGIN getMemoryUsage' );
  my $memoryInfoFile = $plugin->getOptionValue( 'file' );
  my $counterArray = [];
  if ( open( my $fhMemoryInfoFile, '<', $memoryInfoFile ) ) {
    my $memoryInfo = {};
    while ( defined( my $line = <$fhMemoryInfoFile> ) ) {
      chomp ($line);
      if ( "$line" =~ /^([^:]+):\s*([0-9]+)\s+(kB)?$/) {
        my $counterName = "$1";
        my $counterValue = Math::BigFloat->new($2);
        if ( defined( $3 ) ) { 
          $counterValue->bmul(1024); # Memory is given in kB so we convert it in Bytes
        }
        $memoryInfo->{"$counterName"} = "$counterValue";
        &NagiosPlugins::Debug::debug( 2, 'getMemoryUsage', 'Found counter "'.$counterName.'" with value "'.$counterValue.'".' );

        if ( $counterName =~ /^(MemFree|Buffers|Cached)$/ ) {
          &NagiosPlugins::Debug::debug( 1, 'getMemoryUsage', 'Creating nagios counter "'.$counterName.'" with value "'.$counterValue.'".' );
          
          my $counter = { 'name'          => $counterName,                              # Name of counter
                          'value'         => $counterValue,                             # Counter value used to be displayed in main exit message
                          'perfDataValue' => $counterValue,                             # Counter value used to be displayed in performance data output
                          'thresholdType' => 'percentage',                              # Compute threshold as a raw value (none) or a percentage value (percentage)
                          'valueMax'      => $memoryInfo->{'MemTotal'},                 # Value limit to compute percentage
                          'valueLimitMax' => Math::BigFloat->new(2)->bpow(63)->bsub(1), # Counter max value before resetting (2**64) 
                          'valueRound'    => 0,                                         # How many numbers do you want after dot
                          'valueUnit'     => 'B',                                       # Counter unit used to be displayed in main exit message
                          'perfDataUnit'  => 'B' };                                     # Counter unit used to be displayed in performance data output

          push( @{$counterArray}, $counter );
        }
      } else {
        &NagiosPlugins::Debug::debug( 2, 'getMemoryUsage', 'Unable to parse line "'.$line.'" : [IGNORED]' );
      }
    }
  } else {
    &NagiosPlugins::Debug::debug( 9, 'getMemoryUsage', 'END getMemoryUsage' );
    $plugin->exit( 'UNKNOWN','Unable to open file "'.$memoryInfoFile.'" ('.$!.')' );
  }
  &NagiosPlugins::Debug::debug( 9, 'getMemoryUsage', 'END getMemoryUsage' );
  return ($counterArray);
}

my $counterArray = &getMemoryUsage( $plugin );
$plugin->createObject( 'MemoryUsage', $counterArray, 0 );

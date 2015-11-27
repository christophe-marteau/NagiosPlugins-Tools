package NagiosPlugins::Counters;

use warnings;
use strict;
use Carp;
use Math::BigFloat;
use Scalar::Util 'blessed';

our $VERSION = '1.00';

# Function compute call the a function (none, delta, average, rate or user defined ) to compute value or performance data
# [in] $computeType : The type of compute to apply to this counter. It can be on of these defined words :
#                       - 'none' : no compute will be apply
#                       - 'delta' : This formula "v(t2) - v(t1)" will be apply
#                       - 'average' : This formula "( v(t2) - v(t1) ) / ( vl(t2) - vl(t1) )" will be apply
#                       - 'rate' : This formula "( v(t2) - v(t1) ) / ( t2 - t1 )" will be apply
#                       - a function name build by user in the main script (show examples for details)
#                     It assumes that v(t2) is the current value of the counter and v(t1) is the previous value for the counter and that vl is 
#                     a value of a secound counter linked to the v counter.
sub compute() {
  my ( $self, $computeType ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::compute', 'BEGIN compute' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::compute', 'compute( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.', '.$computeType.' )');
  if ( $self->{'_COUNTER_HIDDEN'} ) {
    &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::compute', 'Hidden counter, no compute' );
  } else {
    if ( $computeType =~ /^(VALUE|PERFDATA)$/ ) {
      if ( defined( $self->{'_COUNTER_'.$computeType.'_COMPUTED_FUNCTION'} ) ) {
        $self->{'_COUNTER_'.$computeType.'_COMPUTED_FUNCTION'}->( $self, $computeType );
      } else {
        &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::compute', 'END compute');
        croak( 'Undefined computed function for counter "'.$self->{'_COUNTER_NAME'}.'" with compute type "'.$computeType.'"' );
      }
    } else {
      &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::compute', 'END compute' );
      croak( 'You must use a correct compute type ( '.$computeType.' ) : "VALUE" or "PERFDATA"' );
    }
  }
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::compute', 'compute( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.', '.$computeType.' ) = "'.$self->{'_COUNTER_VALUE_COMPUTED'}.'"' );
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::compute', 'END compute' );
}

# Function none is a compute function that does nothing and leave counter value or perfdata unmodified
# [in] $counter : A counter object
# [in] $computeType : VALUE of PERFDATA to specify where to apply function in counter 
our $none = sub {
  my ( $counter, $computeType ) = @_ ;
  &NagiosPlugins::Debug::debug( 9, 'none', 'BEGIN none' );
  &NagiosPlugins::Debug::debug( 8, 'none', 'none( '.$counter->{'_COUNTER_ID'}.', '.$counter->{'_COUNTER_NAME'}.', '.$computeType.' )');
  my $counterName = '';
  if ( "$computeType" eq "VALUE" ) {
    $counterName = '_COUNTER_VALUE_COMPUTED';
  } elsif ( "$computeType" eq "PERFDATA" ) {
    $counterName = '_COUNTER_PERFDATA_VALUE';
  } else {
    croak( 'You must use a correct compute type ( '.$computeType.' ) : "VALUE" or "PERFDATA"' );
  }
  $counter->{$counterName} = $counter->{'_COUNTER_VALUE'}->copy();
  &NagiosPlugins::Debug::debug( 9, 'none', 'END none' );
};

# Function delta compute function modify counter value or perfdata with this formula : v(t2) - v(t1). It assumes that v(t2) 
# is the current value of the counter and v(t1) is the previous value for the counter.
# [in] $counter : A counter object
# [in] $computeType : VALUE of PERFDATA to specify where to apply function in counter 
our $delta = sub {
  my ( $counter, $computeType ) = @_ ;
  &NagiosPlugins::Debug::debug( 9, 'delta', 'BEGIN delta' );
  &NagiosPlugins::Debug::debug( 8, 'delta', 'delta( '.$counter->{'_COUNTER_ID'}.', '.$counter->{'_COUNTER_NAME'}.', '.$computeType.' )');
  my $counterName = '';
  if ( "$computeType" eq "VALUE" ) {
    $counterName = '_COUNTER_VALUE_COMPUTED';
  } elsif ( "$computeType" eq "PERFDATA" ) {
    $counterName = '_COUNTER_PERFDATA_VALUE';
  } else {
    croak( 'You must use a correct compute type ( '.$computeType.' ) : "VALUE" or "PERFDATA"' );
  }
  if ( $counter->{'_COUNTER_VALUE_PREVIOUS_TIMESTAMP'}->is_nan() ) {
    $counter->{'_COUNTER_MSG'} = 'Initializing counter '.$counter->{'_COUNTER_NAME'};
    $counter->{'_COUNTER_STATE'} = "UNKNOWN";
  } else {
    if ( $counter->{'_COUNTER_VALUE_TIMESTAMP'}->bcmp( $counter->{'_COUNTER_VALUE_PREVIOUS_TIMESTAMP'} ) == 1 ) {
      # We check if old value is set
      if ( $counter->{'_COUNTER_VALUE_PREVIOUS'}->is_nan() ) {
        croak( 'No previous value defined for counter [ '.$counter->{'_COUNTER_ID'}.', '.$counter->{'_COUNTER_NAME'}.' ], perhaps you have to load an object data first ...' );
      } else {
        # we check if old value is lower than current
        if ( $counter->{'_COUNTER_VALUE'}->bcmp( $counter->{'_COUNTER_VALUE_PREVIOUS'} ) == 1 ) {
          $counter->{$counterName} = $counter->{'_COUNTER_VALUE'}->copy()
                                                                 ->bsub( $counter->{'_COUNTER_VALUE_PREVIOUS'} )
                                                                 ->scale( $counter->{'_COUNTER_VALUE_SCALE'} )
                                                                 ->ffround( -$counter->{'_COUNTER_VALUE_ROUND'} );
          &NagiosPlugins::Debug::debug( 7, 'delta', 'Computed value : [ '.$counter->{$counterName}.' ] = round[ '.$counter->{'_COUNTER_VALUE_ROUND'}.' ]( ( currentValue( '.$counter->{'_COUNTER_VALUE'}.' ) - previousValue( '.$counter->{'_COUNTER_VALUE_PREVIOUS'}.' ) ) x scale( '.$counter->{'_COUNTER_VALUE_SCALE'}.' ) )' );
          if ( $counter->{$counterName}->bcmp( $counter->{'_COUNTER_VALUE_MAX'} ) == 1 ) {
            $counter->{'_COUNTER_MSG'} = 'Computed counter value ( '.$counter->{$counterName}.' ) is over counter value limit ( '.$counter->{'_COUNTER_VALUE_MAX'}.' )';
            $counter->{'_COUNTER_STATE'} = 'UNKNOWN';
          }
        # we check if old value is greater than current
        } elsif ( $counter->{'_COUNTER_VALUE'}->bcmp( $counter->{'_COUNTER_VALUE_PREVIOUS'} ) == -1 )  {
          if ( ( $counter->{'_COUNTER_VALUE_LIMIT_MAX'}->is_nan() ) or
               ( $counter->{'_COUNTER_VALUE_LIMIT_MAX'}->is_inf( '-' ) ) or
               ( $counter->{'_COUNTER_VALUE_LIMIT_MAX'}->is_inf( '+' ) ) ) {
            croak( 'No finite max value defined for counter [ '.$counter->{'_COUNTER_ID'}.', '.$counter->{'_COUNTER_NAME'}.' ], perhaps you have to set it ...' );
          } else {
            $counter->{$counterName} = $counter->{'_COUNTER_VALUE'}->copy()
                                                                   ->badd( $counter->{'_COUNTER_VALUE_LIMIT_MAX'} )
                                                                   ->bsub( $counter->{'_COUNTER_VALUE_PREVIOUS'} )
                                                                   ->scale( $counter->{'_COUNTER_VALUE_SCALE'} )
                                                                   ->ffround( -$counter->{'_COUNTER_VALUE_ROUND'} );
            &NagiosPlugins::Debug::debug( 7, 'delta', 'Computed value : [ '.$counter->{$counterName}.' ] = round[ '.$counter->{'_COUNTER_VALUE_ROUND'}.' ]( ( ( currentValue( '.$counter->{'_COUNTER_VALUE'}.' ) + maxValue( '.$counter->{'_COUNTER_VALUE_LIMIT_MAX'}.' ) ) - previousValue( '.$counter->{'_COUNTER_VALUE_PREVIOUS'}.' ) ) x scale( '.$counter->{'_COUNTER_VALUE_SCALE'}.' ) )' );
          }
          if ( $counter->{$counterName}->bcmp( $counter->{'_COUNTER_VALUE_MAX'} ) == 1 ) {
            $counter->{'_COUNTER_MSG'} = 'Computed counter value ('.$counter->{$counterName}.') is over counter value limit ( '.$counter->{'_COUNTER_VALUE_MAX'}.' )';
            $counter->{'_COUNTER_STATE'} = 'UNKNOWN';
          }
        } else {
          # We have same value, delta = 0
          &NagiosPlugins::Debug::debug( 7, 'delta', 'Computed value : [ 0 ] ( previousValue( '.$counter->{'_COUNTER_VALUE_PREVIOUS'}.' ) == currentValue( '.$counter->{'_COUNTER_VALUE_LIMIT_MAX'}.' ) )' );
          $counter->{$counterName} = Math::BigFloat->new( 0 );
        }
      }
    } else {
      $counter->{'_COUNTER_MSG'} = 'Not enough time between old timestamp ( '.$counter->{'_COUNTER_VALUE_PREVIOUS_TIMESTAMP'}.' ) and newtimestamp ( '.$counter->{'_COUNTER_VALUE_TIMESTAMP'}.' )';
      $counter->{'_COUNTER_STATE'} = 'UNKNOWN';
    }
  }
  &NagiosPlugins::Debug::debug( 8, 'delta', 'delta( '.$counter->{'_COUNTER_ID'}.', '.$counter->{'_COUNTER_NAME'}.', '.$computeType.' )= '.$counter->{$counterName} );
  &NagiosPlugins::Debug::debug( 9, 'delta', 'END delta' );
};

# Function average compute function modify counter value or perfdata with this formula : ( v(t2) - v(t1) ) / ( vl(t2) - vl(t1) ).
# It assumes that v(t2) is the current value of the counter and v(t1) is the previous value for the counter and that vl is a value
# of a secound counter linked to the v counter.
# [in] $counter : A counter object
# [in] $computeType : VALUE of PERFDATA to specify where to apply function in counter 
our $average = sub {
  my ( $counter, $computeType ) = @_ ;
  &NagiosPlugins::Debug::debug( 9, 'average', 'BEGIN average' );
  &NagiosPlugins::Debug::debug( 8, 'average', 'average( '.$counter->{'_COUNTER_ID'}.', '.$counter->{'_COUNTER_NAME'}.', '.$computeType.' )');
  # We check first if old timestamp is set and is lower than current timestamp
  my $linkedCounter = undef;
  if ( defined( $counter->{'_COUNTER_LINK'} ) ) {
    $linkedCounter = $counter->{'_COUNTER_LINK'};
  } else {
    croak( 'You must defined a linked counter for counter [ '.$counter->{'_COUNTER_ID'}.', '.$counter->{'_COUNTER_NAME'}.' ] to compute average.' );
  }
  my $counterName = '';
  if ( "$computeType" eq "VALUE" ) {
    $counterName = '_COUNTER_VALUE_COMPUTED';
  } elsif ( "$computeType" eq "PERFDATA" ) {
    $counterName = '_COUNTER_PERFDATA_VALUE';
  } else {
    croak('You must use a correct compute type ( '.$computeType.' ) : "VALUE" or "PERFDATA"');
  }
  if ( $counter->{'_COUNTER_VALUE_PREVIOUS_TIMESTAMP'}->is_nan() ) {
    $counter->{'_COUNTER_MSG'} = 'Initializing counter '.$counter->{'_COUNTER_NAME'};
    $counter->{'_COUNTER_STATE'} = "UNKNOWN";
  } else {
    if ( $counter->{'_COUNTER_VALUE_TIMESTAMP'}->bcmp( $counter->{'_COUNTER_VALUE_PREVIOUS_TIMESTAMP'} ) == 1 ) {
      # We check if old value is set
      if ( $counter->{'_COUNTER_VALUE_PREVIOUS'}->is_nan() ) {
        croak( 'No previous value defined for counter [ '.$counter->{'_COUNTER_ID'}.', '.$counter->{'_COUNTER_NAME'}.' ], perhaps you have to load an object data first ...' );
      } elsif ( $linkedCounter->{'_COUNTER_VALUE_PREVIOUS'}->is_nan() ) {
        croak( 'No previous value defined for counter [ '.$linkedCounter->{'_COUNTER_ID'}.', '.$linkedCounter->{'_COUNTER_NAME'}.' ], perhaps you have to load an object data first ...' );
      } else {
        my $averageBase = Math::BigFloat->new( 0 );
        if ( $linkedCounter->{'_COUNTER_VALUE'}->bcmp( $linkedCounter->{'_COUNTER_VALUE_PREVIOUS'} ) == 1 ) {
          $averageBase = $linkedCounter->{'_COUNTER_VALUE'}->copy()
                                                           ->bsub( $linkedCounter->{'_COUNTER_VALUE_PREVIOUS'} );
          &NagiosPlugins::Debug::debug( 7, 'average', 'Average base  [ '.$averageBase.' ] = ( currentLinkedCounterValue( '.$linkedCounter->{'_COUNTER_VALUE'}.' ) - previousLinkedCounterValue( '.$linkedCounter->{'_COUNTER_VALUE_PREVIOUS'}.' ) )' );
        } else {
          $averageBase = $linkedCounter->{'_COUNTER_VALUE'}->copy()
                                                           ->badd( $linkedCounter->{'_COUNTER_VALUE_LIMIT_MAX'} ) 
                                                           ->bsub( $linkedCounter->{'_COUNTER_VALUE_PREVIOUS'} );
          &NagiosPlugins::Debug::debug( 7, 'average', 'Average base [ '.$averageBase.' ] = ( ( currentLinkedCounterValue( '.$linkedCounter->{'_COUNTER_VALUE'}.' ) + maxLinkedCounterValue( '.$linkedCounter->{'_COUNTER_VALUE_LIMIT_MAX'}.' ) ) - previousLinkedCounterValue( '.$linkedCounter->{'_COUNTER_VALUE_PREVIOUS'}.' ) )' );
        }
        if ( $averageBase->bcmp( 0 ) == 1 ) {
          # we check if old value is lower than current
          if ( $counter->{'_COUNTER_VALUE'}->bcmp( $counter->{'_COUNTER_VALUE_PREVIOUS'} ) == 1 ) {
            $counter->{$counterName} = $counter->{'_COUNTER_VALUE'}->copy()
                                                                   ->bsub( $counter->{'_COUNTER_VALUE_PREVIOUS'} )
                                                                   ->bdiv( $averageBase )
                                                                   ->bmul( $counter->{'_COUNTER_VALUE_SCALE'} )
                                                                   ->ffround( -$counter->{'_COUNTER_VALUE_ROUND'} );
            &NagiosPlugins::Debug::debug( 7, 'average', 'Computed value : [ '.$counter->{$counterName}.' ] = round[ '.$counter->{'_COUNTER_VALUE_ROUND'}.' ]( ( ( currentValue( '.$counter->{'_COUNTER_VALUE'}.' ) - previousValue( '.$counter->{'_COUNTER_VALUE_PREVIOUS'}.' ) ) / averageBase( '.$averageBase.' ) ) x scale( '.$counter->{'_COUNTER_VALUE_SCALE'}.' ) )' );
            if ( $counter->{$counterName}->bcmp($counter->{'_COUNTER_VALUE_MAX'} ) == 1 ) {
              $counter->{'_COUNTER_MSG'} = 'Computed counter value ( '.$counter->{$counterName}.' ) is over counter value limit ( '.$counter->{'_COUNTER_VALUE_MAX'}.' )';
              $counter->{'_COUNTER_STATE'} = 'UNKNOWN';
            }
          # we check if old value is greater than current
          } elsif ( $counter->{'_COUNTER_VALUE'}->bcmp( $counter->{'_COUNTER_VALUE_PREVIOUS'} ) == -1 )  {
            if ( ( $counter->{'_COUNTER_VALUE_LIMIT_MAX'}->is_nan() ) or
                 ( $counter->{'_COUNTER_VALUE_LIMIT_MAX'}->is_inf( '-' ) ) or
                 ( $counter->{'_COUNTER_VALUE_LIMIT_MAX'}->is_inf( '+' ) ) ) {
              croak( 'No finite max value defined for counter [ '.$counter->{'_COUNTER_ID'}.', '.$counter->{'_COUNTER_NAME'}.' ], perhaps you have to set it ...' );
            } else {
              $counter->{$counterName} = $counter->{'_COUNTER_VALUE'}->copy()
                                                                     ->badd( $counter->{'_COUNTER_VALUE_LIMIT_MAX'} )
                                                                     ->bsub( $counter->{'_COUNTER_VALUE_PREVIOUS'} )
                                                                     ->bdiv( $averageBase )
                                                                     ->bmul( $counter->{'_COUNTER_VALUE_SCALE'} )
                                                                     ->ffround( -$counter->{'_COUNTER_VALUE_ROUND'} );
              &NagiosPlugins::Debug::debug( 7, 'average', 'Computed value : [ '.$counter->{$counterName}.' ] = round[ '.$counter->{'_COUNTER_VALUE_ROUND'}.' ]( ( ( ( currentValue( '.$counter->{'_COUNTER_VALUE'}.' ) + maxValue( '.$counter->{'_COUNTER_VALUE_LIMIT_MAX'}.' ) ) - previousValue( '.$counter->{'_COUNTER_VALUE_PREVIOUS'}.' ) ) / averageBase( '.$averageBase.' ) ) x scale( '.$counter->{'_COUNTER_VALUE_SCALE'}.' ) )' );
            }
            if ( $counter->{$counterName}->bcmp( $counter->{'_COUNTER_VALUE_MAX'} ) == 1 ) {
              $counter->{'_COUNTER_MSG'} = 'Computed counter value ( '.$counter->{$counterName}.' ) is over counter value limit ( '.$counter->{'_COUNTER_VALUE_MAX'}.' )';
              $counter->{'_COUNTER_STATE'} = 'UNKNOWN';
            }
          } else {
            # We have same value, average = 0
            &NagiosPlugins::Debug::debug( 7, 'average', 'Computed value : [ 0 ] ( previousValue( '.$counter->{'_COUNTER_VALUE_PREVIOUS'}.' ) == currentValue( '.$counter->{'_COUNTER_VALUE_LIMIT_MAX'}.' ) )' );
            $counter->{$counterName} = Math::BigFloat->new( 0 );
          }
        } else {
          $counter->{'_COUNTER_MSG'} = 'Average base is zero. We can\'t compute average';
          $counter->{'_COUNTER_STATE'} = 'UNKNOWN';
        }
      }
    } else {
      $counter->{'_COUNTER_MSG'} = 'Not enough time between old timestamp ( '.$counter->{'_COUNTER_VALUE_PREVIOUS_TIMESTAMP'}.' ) and newtimestamp ( '.$counter->{'_COUNTER_VALUE_TIMESTAMP'}.' )';
      $counter->{'_COUNTER_STATE'} = 'UNKNOWN';
    }
  }
  &NagiosPlugins::Debug::debug( 8, 'average', 'average( '.$counter->{'_COUNTER_ID'}.', '.$counter->{'_COUNTER_NAME'}.', '.$computeType.' ) = '.$counter->{$counterName} );
  &NagiosPlugins::Debug::debug( 9, 'average', 'END average' );
};

# Function average compute function modify counter value or perfdata with this formula : ( v(t2) - v(t1) ) / ( t2 - t1 ).
# It assumes that v(t2) is the current value of the counter and v(t1) is the previous value for the counter.
# [in] $counter : A counter object
# [in] $computeType : VALUE of PERFDATA to specify where to apply function in counter 
our $rate = sub {
  my ( $counter, $computeType ) = @_ ;
  &NagiosPlugins::Debug::debug( 9, 'rate', 'BEGIN rate' );
  &NagiosPlugins::Debug::debug( 8, 'rate', 'rate( '.$counter->{'_COUNTER_ID'}.', '.$counter->{'_COUNTER_NAME'}.', '.$computeType.' )' );
  # We check first if old timestamp is set and is lower than current timestamp
  my $counterName = '';
  if ( "$computeType" eq "VALUE" ) {
    $counterName = '_COUNTER_VALUE_COMPUTED';
  } elsif ( "$computeType" eq "PERFDATA" ) {
    $counterName = '_COUNTER_PERFDATA_VALUE';
  } else {
    croak( 'You must use a correct compute type ( '.$computeType.' ) : "VALUE" or "PERFDATA"' );
  }
  if ( $counter->{'_COUNTER_VALUE_PREVIOUS_TIMESTAMP'}->is_nan() ) {
    $counter->{'_COUNTER_MSG'} = 'Initializing counter '.$counter->{'_COUNTER_NAME'};
    $counter->{'_COUNTER_STATE'} = "UNKNOWN";
  } else {
    if ( $counter->{'_COUNTER_VALUE_TIMESTAMP'}->bcmp( $counter->{'_COUNTER_VALUE_PREVIOUS_TIMESTAMP'} ) == 1 ) {
      my $elapsedTime = $counter->{'_COUNTER_VALUE_TIMESTAMP'}->copy()->bsub( $counter->{'_COUNTER_VALUE_PREVIOUS_TIMESTAMP'} );
      &NagiosPlugins::Debug::debug( 7, 'rate', 'Elapsed time from last check : [ '.$elapsedTime.' ] = timeStamp( '.$counter->{'_COUNTER_VALUE_TIMESTAMP'}.' ) - previousTimeStamp( '.$counter->{'_COUNTER_VALUE_PREVIOUS_TIMESTAMP'}.' )' );
      # We check if old value is set
      if ( $counter->{'_COUNTER_VALUE_PREVIOUS'}->is_nan() ) {
        croak( 'No previous value defined for counter [ '.$counter->{'_COUNTER_ID'}.', '.$counter->{'_COUNTER_NAME'}.' ], perhaps you have to load an object data first ...' );
      } else {
        # we check if old value is lower than current
        if ( $counter->{'_COUNTER_VALUE'}->bcmp( $counter->{'_COUNTER_VALUE_PREVIOUS'} ) == 1 ) {
          $counter->{$counterName} = $counter->{'_COUNTER_VALUE'}->copy()
                                                                 ->bsub( $counter->{'_COUNTER_VALUE_PREVIOUS'} )
                                                                 ->bdiv( $elapsedTime )
                                                                 ->bmul( $counter->{'_COUNTER_VALUE_SCALE'} )
                                                                 ->ffround( -$counter->{'_COUNTER_VALUE_ROUND'} );
          &NagiosPlugins::Debug::debug( 7, 'rate', 'Computed value : [ '.$counter->{$counterName}.' ] = round[ '.$counter->{'_COUNTER_VALUE_ROUND'}.' ]( ( ( currentValue( '.$counter->{'_COUNTER_VALUE'}.' ) - previousValue( '.$counter->{'_COUNTER_VALUE_PREVIOUS'}.' ) ) / elapsedTime( '.$elapsedTime.' ) ) x scale( '.$counter->{'_COUNTER_VALUE_SCALE'}.' ) )');
          if ( $counter->{$counterName}->bcmp( $counter->{'_COUNTER_VALUE_MAX'} ) == 1 ) {
            $counter->{'_COUNTER_MSG'} = 'Computed counter value ( '.$counter->{$counterName}.' ) is over counter value limit ( '.$counter->{'_COUNTER_VALUE_MAX'}.' )';
            $counter->{'_COUNTER_STATE'} = 'UNKNOWN';
          }
        # we check if old value is greater than current
        } elsif ( $counter->{'_COUNTER_VALUE'}->bcmp( $counter->{'_COUNTER_VALUE_PREVIOUS'} ) == -1 )  {
          if ( ( $counter->{'_COUNTER_VALUE_LIMIT_MAX'}->is_nan() ) or
               ( $counter->{'_COUNTER_VALUE_LIMIT_MAX'}->is_inf( '-' ) ) or
               ( $counter->{'_COUNTER_VALUE_LIMIT_MAX'}->is_inf( '+' ) ) ) {
            croak( 'No finite max value defined for counter [ '.$counter->{'_COUNTER_ID'}.', '.$counter->{'_COUNTER_NAME'}.' ], perhaps you have to set it ...' );
          } else {
            $counter->{$counterName} = $counter->{'_COUNTER_VALUE'}->copy()
                                                                   ->badd( $counter->{'_COUNTER_VALUE_LIMIT_MAX'} )
                                                                   ->bsub( $counter->{'_COUNTER_VALUE_PREVIOUS'} )
                                                                   ->bdiv( $elapsedTime )
                                                                   ->bmul( $counter->{'_COUNTER_VALUE_SCALE'} )
                                                                   ->ffround( -$counter->{'_COUNTER_VALUE_ROUND'} );
            &NagiosPlugins::Debug::debug( 7, 'rate', 'Computed value : [ '.$counter->{$counterName}.' ] = round[ '.$counter->{'_COUNTER_VALUE_ROUND'}.' ]( ( ( ( ( currentValue( '.$counter->{'_COUNTER_VALUE'}.' ) + maxValue( '.$counter->{'_COUNTER_VALUE_LIMIT_MAX'}.' ) ) - previousValue( '.$counter->{'_COUNTER_VALUE_PREVIOUS'}.' ) ) / elapsedTime( '.$elapsedTime.' ) ) ) x scale( '.$counter->{'_COUNTER_VALUE_SCALE'}.' ) )' );
          }
          if ( $counter->{$counterName}->bcmp( $counter->{'_COUNTER_VALUE_MAX'} ) == 1 ) {
            $counter->{'_COUNTER_MSG'} = 'Computed counter value ( '.$counter->{$counterName}.' ) is over counter value limit ( '.$counter->{'_COUNTER_VALUE_MAX'}.' )';
            $counter->{'_COUNTER_STATE'} = 'UNKNOWN';
          }
        } else {
          # We have same value, rate = 0
          &NagiosPlugins::Debug::debug( 7, 'rate', 'Computed value : [ 0 ] ( previousValue( '.$counter->{'_COUNTER_VALUE_PREVIOUS'}.' ) == currentValue( '.$counter->{'_COUNTER_VALUE_LIMIT_MAX'}.' ) )' );
          $counter->{$counterName} = Math::BigFloat->new( 0 );
        }
      }
    } else {
      $counter->{'_COUNTER_MSG'} = 'Not enough time between old timestamp ( '.$counter->{'_COUNTER_VALUE_PREVIOUS_TIMESTAMP'}.' ) and newtimestamp ( '.$counter->{'_COUNTER_VALUE_TIMESTAMP'}.' )';
      $counter->{'_COUNTER_STATE'} = 'UNKNOWN';
    }
  }
  &NagiosPlugins::Debug::debug( 8, 'rate', 'rate( '.$counter->{'_COUNTER_ID'}.', '.$counter->{'_COUNTER_NAME'}.', '.$computeType.' ) = '.$counter->{$counterName} );
  &NagiosPlugins::Debug::debug( 9, 'rate', 'END rate' );
};

# Function convertToHumanReadable try to convert values in human readable values displayed in nagios message
# [in] $value : The value to convert in human readable
# [in] $unit : The unit of the value. Must be 'seconds', 'bytes', 'octets' or 'bits'
# Support only theses units : 
#   - seconds
#   - bytes/octets
#   - bits
# Support only unit factors :
#   - milli, micro, nano, pico,
#   - kilo, mega, giga, tera, peta, exa, zetta, yotta
sub convertToHumanReadable() {
 my ( $value, $unit ) = @_;
 &NagiosPlugins::Debug::debug( 9, 'convertToHumanReadable', 'BEGIN convertToHumanReadable' );
 &NagiosPlugins::Debug::debug( 8, 'convertToHumanReadable', 'convertToHumanReadable( '.$value.', '.$unit.')' );
 my $realValue = Math::BigFloat->new($value);
 my $realBase = Math::BigFloat->new(1000);
 my $realUnit = '';
 my $convertedValue = Math::BigFloat->new(0);
 my $convertedUnit = '';
 my $converted = 1;
 my $realValueSign = $realValue->sign();
 my $unitPrefix = { '0' => '',
                    '-1' => 'm',
                    '-2' => 'u',
                    '-3' => 'n',
                    '-4' => 'p',
                    '1' => 'k',
                    '2' => 'M',
                    '3' => 'G',
                    '4' => 'T',
                    '5' => 'P',
                    '6' => 'E',
                    '7' => 'Z',
                    '8' => 'Y'
                  };
  if ( $unit =~ /^\s*(s|sec|seconds?)\s*$/ ) {
    $realUnit = 's';
  } elsif ( $unit =~ /^\s*([oObB])(ctet|it|yte)?s?(\s*\/\s*s)?\s*$/ ){
    my $unitParsed = $1;
    my $unitParsedRate = $3;
    if ( defined ( $unitParsedRate ) ) {
      &NagiosPlugins::Debug::debug( 7, 'convertToHumanReadable', 'We have parsed unit and found "'.$unitParsed.'" and "'.$unitParsedRate.'"' );
      $realUnit = $unitParsed.'/s';
    } else { 
      &NagiosPlugins::Debug::debug( 7, 'convertToHumanReadable', 'We have parsed unit and found "'.$unitParsed.'"' );
      $realUnit = $unitParsed;
    }
    $realBase = Math::BigFloat->new( 1024 );
  } else {
    $realUnit = $unit;
    $realUnit =~ s/^\s*(\S+)\s*/$1/;
    $converted = 0;
  }
  if ( ( $converted ) and ( $realValue->bcmp( 0 ) != 0 ) ) {
    my $unitFactor = Math::BigFloat->bzero();
    my $realValueCompute = $realValue->copy()->babs();
    if ( $realValueCompute->bcmp( 1 ) == 1 ) {
      &NagiosPlugins::Debug::debug( 7, 'convertToHumanReadable', 'We have an absolute value '.$realValueCompute.' > 1' );
      while ( ( $realValueCompute->bdiv( $realBase )->bcmp( 1 ) == 1 ) and ( $unitFactor->bcmp( 8 ) == -1 ) ) {
        $unitFactor->binc();
        &NagiosPlugins::Debug::debug( 8, 'convertToHumanReadable', 'Processing value '.$realValueCompute.' ( unitFactor = '.$unitFactor.' )' );
      }
      &NagiosPlugins::Debug::debug( 6, 'convertToHumanReadable', 'We have an absolute value '.$realValueCompute.' with unitFactor [ '.$unitFactor.' => "'.$unitPrefix->{$unitFactor}.'" ]' );
      $realValue->bdiv( $realBase->bpow( $unitFactor ) )->ffround( -1 );
    } elsif ( $realValueCompute->bcmp( 1 ) == -1 ) {
      &NagiosPlugins::Debug::debug( 7, 'convertToHumanReadable', 'We have an absolute value '.$realValueCompute.' < 1' );
      while ( ( $realValueCompute->bmul( $realBase )->bcmp( 1 ) == -1 ) and ( $unitFactor->bcmp( -3 ) == 1 ) ) {
        $unitFactor->bdec();
        &NagiosPlugins::Debug::debug( 8, 'convertToHumanReadable', 'Processing value '.$realValueCompute.' ( unitFactor = '.$unitFactor.' )' );
      }
      $unitFactor->bdec;
      &NagiosPlugins::Debug::debug( 6, 'convertToHumanReadable', 'We have an absolute value '.$realValueCompute.' with unitFactor [ '.$unitFactor.' => "'.$unitPrefix->{$unitFactor}.'" ]' );
      $realValue->bmul( $realBase->bpow( $unitFactor->copy()->babs() ) )->ffround( -1 );
    }
    if ( defined( $unitPrefix->{$unitFactor} ) ) {
      &NagiosPlugins::Debug::debug( 8, 'convertToHumanReadable', 'Removing unwanted zero ...' );
      my $unWantedZero = $realValue->bstr();
      $unWantedZero =~ s/\.0+$//;
      $convertedValue = $unWantedZero.$unitPrefix->{$unitFactor}.$realUnit;
    } else {
      &NagiosPlugins::Debug::debug( 6, 'convertToHumanReadable', 'Unit factor ('.$unitFactor.') not known, no convertion ...' );
      $convertedValue = $value.$realUnit;
    }
  } else {
    &NagiosPlugins::Debug::debug( 6, 'convertToHumanReadable', 'Unit not known, not converting anything ...' );
    $convertedValue = $value.$realUnit;
  }

  &NagiosPlugins::Debug::debug( 8, 'convertToHumanReadable', 'convertToHumanReadable( '.$value.', '.$unit.') = ( '.$convertedValue.' )' );
  &NagiosPlugins::Debug::debug( 9, 'convertToHumanReadable', 'END convertToHumanReadable' );
  return( $convertedValue );
}

# Function parseThreshold is use to parse counters warning and critical thresholds, start and end thresholds ranges, and to check if ranges are sane
sub parseThreshold () {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::parseThreshold', 'BEGIN parseThreshold' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::parseThreshold', 'parseThreshold( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' )' );
  if ( $self->{'_COUNTER_HIDDEN'} ) {
    &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::parseThreshold', 'Hidden counter, nothing to do.' );
  } else {
    my $rangeType = 'outside';
    foreach my $thresholdType ( 'WARNING', 'CRITICAL' ) {
      if ( "$self->{'_COUNTER_'.$thresholdType.'_THRESHOLD'}" =~ /^(\@)?(-?[\d.]+|~)(:(-?[\d.]+)?)?$/ ) {
        my $startRangeValue;
        my $endRangeValue;
        if ( defined( $1 ) ) {
          $rangeType = "inside";
        }
        &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::parseThreshold', 'Range Type : '.$rangeType );
        if ( $2 eq '~' ) {
          $startRangeValue = Math::BigFloat->binf( '-' );
        } else {
          $startRangeValue = Math::BigFloat->new( $2 );
        }
        if ( defined( $3 ) ) {
          if ( defined( $4 ) ) {
            $endRangeValue = Math::BigFloat->new( $4 );
            if ( $endRangeValue->bcmp( $startRangeValue ) == -1 ) {
              $self->{'_COUNTER_MSG'} = 'End range value ('.$endRangeValue.') must be equal or greater than start range value ('.$startRangeValue.') for '.$thresholdType.' threshold';
              $self->{'_COUNTER_STATE'} = 'UNKNOWN';
            }
          } else {
            # End range is undefined set to infinite
            $endRangeValue = Math::BigFloat->binf();
          }
        } else {
          # If end range value is not defined, start range become end
          # range and start range=0
          if ( $startRangeValue->is_inf( '-' ) ) {
            $endRangeValue = Math::BigFloat->binf();
          } else {
            $endRangeValue = Math::BigFloat->new( $startRangeValue );
          }
          $startRangeValue = Math::BigFloat->new( 0 );
        }
        # End range value must be equal or greater than start range value
        if ( $endRangeValue->bcmp( $startRangeValue ) == -1 ) {
          $self->{'_COUNTER_MSG'} = 'End range value ( '.$endRangeValue.' ) must be equal or greater than start range value ( '.$startRangeValue.' ) for '.$thresholdType.' threshold';
          $self->{'_COUNTER_STATE'} = 'UNKNOWN';
        } else {
          $self->{'_COUNTER_'.$thresholdType.'_THRESHOLD_MIN'} = Math::BigFloat->new( $startRangeValue );
          $self->{'_COUNTER_'.$thresholdType.'_THRESHOLD_MAX'} = Math::BigFloat->new( $endRangeValue );
          $self->{'_COUNTER_'.$thresholdType.'_THRESHOLD_RANGE_TYPE'} = $rangeType;
        }
      } else {
        $self->{'_COUNTER_MSG'} = 'Unable to parse '.$thresholdType.' threshold ( '.$self->{'_COUNTER_'.$thresholdType.'_THRESHOLD'}.' )';
        $self->{'_COUNTER_STATE'} = 'UNKNOWN';
      }
      &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::parseThreshold', $self->{'_COUNTER_'.$thresholdType.'_THRESHOLD_MIN'}.' < '.
                                                                          $self->{'_COUNTER_NAME'}.' ( '.$thresholdType.' ) < '.
                                                                          $self->{'_COUNTER_'.$thresholdType.'_THRESHOLD_MAX'} );
    }
    if ( $rangeType eq 'inside' ) {
      if ( $self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'}->bcmp( $self->{'_COUNTER_WARNING_THRESHOLD_MIN'} ) == -1 ) {
        $self->{'_COUNTER_MSG'} = 'Min critical threshold range is not inside warning threshold range ( '.
                                  $self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'}.' < '.
                                  $self->{'_COUNTER_WARNING_THRESHOLD_MIN'}.' )';
        $self->{'_COUNTER_STATE'} = 'UNKNOWN';
      } else {
        &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::parseThreshold', 'Min critical threshold range is inside warning threshold range ( '.
                                                                            $self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'}.' > '.
                                                                            $self->{'_COUNTER_WARNING_THRESHOLD_MIN'}.' ).' );
      }
      if ( $self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'}->bcmp( $self->{'_COUNTER_WARNING_THRESHOLD_MAX'} ) == 1 ) {
        $self->{'_COUNTER_MSG'} = 'Max critical threshold range is not inside warning threshold range ( '.
                                  $self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'}.' > '.
                                  $self->{'_COUNTER_WARNING_THRESHOLD_MAX'}.' )';
        $self->{'_COUNTER_STATE'} = 'UNKNOWN';
      } else {
        &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::parseThreshold', 'Max critical threshold range is inside warning threshold range ( '.
                                                                            $self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'}.' < '.
                                                                            $self->{'_COUNTER_WARNING_THRESHOLD_MAX'}.' ).' );
      }
    } else {
      if ( $self->{'_COUNTER_WARNING_THRESHOLD_MIN'}->bcmp( $self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'} ) == -1 ) {
        $self->{'_COUNTER_MSG'} = 'Min warning threshold range is not inside critical threshold range ( '.
                                  $self->{'_COUNTER_WARNING_THRESHOLD_MIN'}.' < '.
                                  $self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'}.' )';
        $self->{'_COUNTER_STATE'} = 'UNKNOWN';
      } else {
        &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::parseThreshold', 'Min warning threshold range is inside critical threshold range ( '.
                                                                            $self->{'_COUNTER_WARNING_THRESHOLD_MIN'}.' > '.
                                                                            $self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'}.' ).' );
      }
      if ( $self->{'_COUNTER_WARNING_THRESHOLD_MAX'}->bcmp( $self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'} ) == 1 ) {
        $self->{'_COUNTER_MSG'} = 'Max warning threshold range is not inside critical threshold range ( '.
                                  $self->{'_COUNTER_WARNING_THRESHOLD_MAX'}.' > '.
                                  $self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'}.' )';
        $self->{'_COUNTER_STATE'} = 'UNKNOWN';
      } else {
        &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::parseThreshold', 'Max warning threshold range is inside critical threshold range ( '.
                                                                            $self->{'_COUNTER_WARNING_THRESHOLD_MAX'}.' < '.
                                                                            $self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'}.' ).');
      }
    }
  }  
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::parseThreshold', 'END parseThreshold' );
}

# Function checkThreshold is used to check if value is in warning or critical range
sub checkThreshold () {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::checkThreshold', 'BEGIN checkThreshold' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::checkThreshold', 'checkThreshold( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' )' );
  if ( $self->{'_COUNTER_HIDDEN'} ) {
    &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::checkThreshold', 'Hidden counter, nothing to do.' );
  } else {
    if ( ( defined( $self->{'_COUNTER_VALUE_COMPUTED'} ) ) and ( not( $self->{'_COUNTER_VALUE_COMPUTED'}->is_nan() ) ) ) {
      my $counterValue = Math::BigFloat->new( 0 );
      if ( $self->{'_COUNTER_THRESHOLD_TYPE'} eq 'none' ) {
        $counterValue = $self->{'_COUNTER_VALUE_COMPUTED'}->copy();
      } elsif ( $self->{'_COUNTER_THRESHOLD_TYPE'} eq 'percentage' ) {
        if ( ( $self->{'_COUNTER_VALUE_MAX'}->is_nan() ) or
             ( $self->{'_COUNTER_VALUE_MAX'}->is_inf( '-' ) ) or
             ( $self->{'_COUNTER_VALUE_MAX'}->is_inf( '+' ) ) ) {
          croak( 'No finite value limit defined for counter [ '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ], perhaps you have to set it ...' );
        } else {
          if ( $self->{'_COUNTER_VALUE_MAX'}->is_zero() ) {
            croak( 'Can\'t compute a percentage if value limit is 0 for counter [ '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ], perhaps you have to set it to 0.001' );
          } else {
            $counterValue = $self->{'_COUNTER_VALUE_COMPUTED'}->copy()
                                                              ->bmul( 100 ) 
                                                              ->bdiv( $self->{'_COUNTER_VALUE_MAX'} )
                                                              ->ffround( '-'.$self->{'_COUNTER_VALUE_ROUND'} );
            &NagiosPlugins::Debug::debug( 7, blessed( $self ).'::checkThreshold', 'Compute round[ '.$self->{'_COUNTER_VALUE_ROUND'}.' ]( '.$self->{'_COUNTER_VALUE_COMPUTED'}.' x 100 / '.$self->{'_COUNTER_VALUE_MAX'}.' ) = "'.$counterValue.'"' );
          }
          &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::checkThreshold', 'Converting value "'.$self->{'_COUNTER_VALUE_COMPUTED'}.'" in percentage : "'.$counterValue.'"' );
          $self->{'_COUNTER_VALUE_LABEL'} .= ' '.$counterValue.'%';
        }
      } else {
        croak( 'Undefined counter threshold type "'.$self->{'_COUNTER_THRESHOLD_TYPE'}.'" ( must be "none" or "percentage" )' );
      } 
      &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::checkThreshold', 'Checking value '.$counterValue.' ( '.$self->{'_COUNTER_VALUE_COMPUTED'}.' ) for counter "'.$self->{'_COUNTER_NAME'}.'" ...' );
     
      my $extendedLabel = &convertToHumanReadable( $self->{'_COUNTER_VALUE_COMPUTED'}, $self->{'_COUNTER_VALUE_UNIT'} );
      if ( $self->{'_COUNTER_THRESHOLD_TYPE'} eq 'percentage' ) {
        my $maxValueLabel = &convertToHumanReadable( $self->{'_COUNTER_VALUE_MAX'}, $self->{'_COUNTER_VALUE_UNIT'} );
        $extendedLabel .= ' / '.$maxValueLabel;
      }
      # We check if we raise a critical state
      if ( $self->{'_COUNTER_CRITICAL_THRESHOLD_RANGE_TYPE'} eq 'outside' ) {
        # Check for value outside critical threshold range
        if ( ( $counterValue->bcmp( $self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'} ) == -1 ) or 
             ( $counterValue->bcmp( $self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'} ) == 1 ) ) {
          $self->{'_COUNTER_MSG'} = $self->{'_COUNTER_VALUE_LABEL'}.' ('.$extendedLabel.
                                    ') is out of critical range ['.$self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'}.' .. '.
                                    $self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'}.']';
          $self->{'_COUNTER_STATE'} = 'CRITICAL';
        }
      } elsif ( $self->{'_COUNTER_CRITICAL_THRESHOLD_RANGE_TYPE'} eq 'inside' ) {
        # Check for value outside critical threshold range
        if ( not( ( $counterValue->bcmp( $self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'} ) == 1 ) or
             ( $counterValue->bcmp( $self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'} ) == -1 ) ) ) {
          $self->{'_COUNTER_MSG'} = $self->{'_COUNTER_VALUE_LABEL'}.' ('.$extendedLabel.
                                    ') is in critical range ['.$self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'}.' .. '.
                                    $self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'}.']';
          $self->{'_COUNTER_STATE'} = 'CRITICAL';
        }
      } else {
        croak( 'BUG : Undefined critical range type "'.$self->{'_COUNTER_CRITICAL_THRESHOLD_RANGE_TYPE'}.'" for counter "'.$self->{'_COUNTER_NAME'}.'".' );
      }
      if ( $self->{'_COUNTER_STATE'} ne 'CRITICAL' ) {
        # No critical state found, we check if we raise a warning state  
        if ( $self->{'_COUNTER_WARNING_THRESHOLD_RANGE_TYPE'} eq 'outside' ) {
          # Check for value outside warning threshold range
          if ( ( $counterValue->bcmp( $self->{'_COUNTER_WARNING_THRESHOLD_MIN'} ) == -1 ) or
               ( $counterValue->bcmp( $self->{'_COUNTER_WARNING_THRESHOLD_MAX'} ) == 1 ) ) {
            $self->{'_COUNTER_MSG'} = $self->{'_COUNTER_VALUE_LABEL'}.' ('.$extendedLabel.
                                      ') is out of warning range ['.$self->{'_COUNTER_WARNING_THRESHOLD_MIN'}.' .. '.
                                      $self->{'_COUNTER_WARNING_THRESHOLD_MAX'}.']';
            $self->{'_COUNTER_STATE'} = 'WARNING';
          } else {
            # No critical or warning state found, we are in an OK state
            $self->{'_COUNTER_MSG'} = $self->{'_COUNTER_VALUE_LABEL'}.' ('.$extendedLabel.')' ;
            $self->{'_COUNTER_STATE'} = 'OK';
    
          }
        } elsif ( $self->{'_COUNTER_WARNING_THRESHOLD_RANGE_TYPE'} eq 'inside' ) {
          # Check for value inside warning threshold range
          if ( ( $counterValue->bcmp( $self->{'_COUNTER_WARNING_THRESHOLD_MAX'} ) == 1 ) or
               ( $counterValue->bcmp( $self->{'_COUNTER_WARNING_THRESHOLD_MIN'} ) == -1 ) ) {
            # No critical or warning state found, we are in an OK state
            $self->{'_COUNTER_MSG'} = $self->{'_COUNTER_VALUE_LABEL'}.' ('.$extendedLabel.')' ;
            $self->{'_COUNTER_STATE'} = 'OK';
          } else {
            $self->{'_COUNTER_MSG'} = $self->{'_COUNTER_VALUE_LABEL'}.' ('.$extendedLabel.
                                      ') is in warning range ['.$self->{'_COUNTER_WARNING_THRESHOLD_MIN'}.' .. '.
                                      $self->{'_COUNTER_WARNING_THRESHOLD_MAX'}.']';
            $self->{'_COUNTER_STATE'} = 'WARNING';
          }
        } else {
          croak( 'BUG : Undefined warning range type "'.$self->{'_COUNTER_WARNING_THRESHOLD_RANGE_TYPE'}.
                 '" for counter "'.$self->{'_COUNTER_NAME'}.'".' );
        }
      } 
      &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::checkThreshold', $self->{'_COUNTER_MSG'}.' : ['.$self->{'_COUNTER_STATE'}.']' );
    } else {
      croak( 'Undefined or bad value "'.$self->{'_COUNTER_VALUE_COMPUTED'}.'" for counter "'.$self->{'_COUNTER_NAME'}.'".' );
    }
  }
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::checkThreshold', 'END checkThreshold' );
}

# Function isHidden check if a counter if hidden or not
sub isHidden() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::isHidden', 'BEGIN isHidden' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::isHidden', 'isHidden( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ) = '.$self->{'_COUNTER_HIDDEN'} );
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::isHidden', 'END isHidden' );
  return( $self->{'_COUNTER_HIDDEN'} );
}

# Function getId return counter's id
# [return] the counter ID.
sub getId() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getId', 'BEGIN getId' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::getId', 'getId( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ) = '.$self->{'_COUNTER_ID'} );
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getId', 'END getId' );
  return( $self->{'_COUNTER_ID'} );
}

# Function getLinkName return the name of the linked counter's or undef if no linked counter is found. A linked counter is needed to compute average.
# [return] the linked counter's name
sub getLinkName() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getLinkName', 'BEGIN getLinkName' );
  if ( defined ( $self->{'_COUNTER_LINK_NAME'} ) ) {
    &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::getLinkName', 'getLinkName( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ) = '.$self->{'_COUNTER_LINK_NAME'} );
  } else {
    &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::getLinkName', 'getLinkName( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ) = undef' );
  }
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getLinkName', 'END getLinkName' );
  return( $self->{'_COUNTER_LINK_NAME'} );
}

# Function getPerfDataMsg return nagios performance data message or undef if it is an hidden counter
# [return] the nagios performance data message or undef if it is an hidden counter
sub getPerfDataMsg() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getPerfDataMsg', 'BEGIN getPerfDataMsg');
  if ( $self->{'_COUNTER_HIDDEN'} ) {
    &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::getPerfDataMsg', 'Hidden counter ...' );
    &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::getPerfDataMsg', 'getPerfDataMsg( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ) = undef' );
    &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getPerfDataMsg', 'END getPerfDataMsg');
    return( undef );
  } else {
    &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::getPerfDataMsg', 'getPerfDataMsg( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.') = '.$self->{'_COUNTER_PERFDATA_MSG'} );
    &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getPerfDataMsg', 'END getPerfDataMsg' );
    return( $self->{'_COUNTER_PERFDATA_MSG'} );
  }
}

# Function getMsg return nagios message or undef if it is an hidden counter
# [return] the nagios message or undef if it is an hidden counter
sub getMsg() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getMsg', 'BEGIN getMsg' );
  if ( $self->{'_COUNTER_HIDDEN'} ) {
    &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::getMsg', 'Hidden counter ...' );
    &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::getMsg', 'getMsg( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ) = undef' );
    &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getMsg', 'END getMsg' );
    return( undef );
  } else {
    &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::getMsg', 'getMsg( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ) = '.$self->{'_COUNTER_MSG'} );
    &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getMsg', 'END getMsg' );
    return( $self->{'_COUNTER_MSG'} );
  }
}

# Function getState return nagios state or undef if it is an hidden counter
# [return] the nagios state or undef if it is an hidden counter
sub getState() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getState', 'BEGIN getState' );
  if ( $self->{'_COUNTER_HIDDEN'} ) {
    &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::getState', 'getState( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ) = undef' );
    &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getState', 'END getState' );
    return( undef );
  } else {
    &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::getState', 'getState( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ) = '.$self->{'_COUNTER_STATE'} );
    &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getState', 'END getState' );
    return( $self->{'_COUNTER_STATE'} );
  }
}

# Function getName return counter's name
# [return] the counter's name
sub getName() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getName', 'BEGIN getName');
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::getName', 'getName( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ) = '.$self->{'_COUNTER_NAME'});
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getName', 'END getName');
  return( $self->{'_COUNTER_NAME'} );
}

# Function getValue return counter's value
# [return] the counter's value
sub getValue() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getValue', 'BEGIN getValue');
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::getValue', 'getValue( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ) = '.$self->{'_COUNTER_VALUE'});
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getValue', 'END getValue');
  return( $self->{'_COUNTER_VALUE'} );
}

# This function set nagios perfdata message for a counter
sub setPerfData() {
  my ( $self ) = @_ ;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::setPerfData', 'BEGIN setPerfData' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::setPerfData', 'setPerfData('.$self->{'_COUNTER_ID'}.','.$self->{'_COUNTER_NAME'}.')' );
  # We can defined limit min and limit max if these values are not inf or nan
  my $perfDataLimit = ';;';
  if ( ( $self->{'_COUNTER_VALUE_MAX'}->is_nan() ) or ( $self->{'_COUNTER_VALUE_MIN'}->is_nan() ) or
       ( $self->{'_COUNTER_VALUE_MAX'}->is_inf( '+' ) ) or ( $self->{'_COUNTER_VALUE_MIN'}->is_inf( '+' ) ) or
       ( $self->{'_COUNTER_VALUE_MAX'}->is_inf( '-' ) ) or ( $self->{'_COUNTER_VALUE_MIN'}->is_inf( '-' ) ) or
       ( $self->{'_COUNTER_VALUE_MAX'}->bcmp( $self->{'_COUNTER_VALUE_MIN'} ) <= 0 ) ) {
    &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::setPerfData', 'Performance data limits can\'t be defined (limit min = "'.$self->{'_COUNTER_VALUE_MIN'}.'" and limit max = "'.$self->{'_COUNTER_VALUE_MAX'}.'" : No print' );
  } else {
    $perfDataLimit = $self->{'_COUNTER_VALUE_MIN'}.';'.$self->{'_COUNTER_VALUE_MAX'};
  }

  &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::setPerfData', 'Counter perfdata value : "'.$self->{'_COUNTER_PERFDATA_VALUE'}.'" ('.ref($self->{'_COUNTER_PERFDATA_VALUE'}).')' );
  if ( ( defined( $self->{'_COUNTER_PERFDATA_VALUE'} ) ) and ( not( $self->{'_COUNTER_PERFDATA_VALUE'}->is_nan() ) ) ) {
  
    my $warningPerfDataThreshold = '';
    my $criticalPerfDataThreshold = '';
  
    if ( $self->{'_COUNTER_WARNING_THRESHOLD_RANGE_TYPE'} eq $self->{'_COUNTER_CRITICAL_THRESHOLD_RANGE_TYPE'} ) {
      if ( ( ( $self->{'_COUNTER_WARNING_THRESHOLD_MAX'}->is_inf( '+' ) ) or ( $self->{'_COUNTER_WARNING_THRESHOLD_MAX'}->is_zero() ) ) and 
           ( ( $self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'}->is_inf( '+' ) ) or ( $self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'}->is_zero() ) ) and
           ( not( $self->{'_COUNTER_WARNING_THRESHOLD_MIN'}->is_inf( '-' ) ) ) and
           ( not( $self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'}->is_inf( '-' ) ) ) ) {
        # We can defind min if max is +inf or 0 and min is not -inf
        my $counterWarningThresholdMin = 0;
        my $counterCriticalThresholdMin = 0;
        if ( $self->{'_COUNTER_THRESHOLD_TYPE'} eq 'none' ) {
          $counterWarningThresholdMin = $self->{'_COUNTER_WARNING_THRESHOLD_MIN'}->copy();
          $counterCriticalThresholdMin = $self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'}->copy();
        } elsif ( $self->{'_COUNTER_THRESHOLD_TYPE'} eq 'percentage' ) {
          if ( ( $self->{'_COUNTER_VALUE_MAX'}->is_nan() ) or
               ( $self->{'_COUNTER_VALUE_MAX'}->is_inf( '-' ) ) or
               ( $self->{'_COUNTER_VALUE_MAX'}->is_inf( '+' ) ) ) {
            croak( 'No finite value limit defined for counter [ '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ], perhaps you have to set it ...' );
          } else { 
            $counterWarningThresholdMin = $self->{'_COUNTER_WARNING_THRESHOLD_MIN'}->copy()
                                                                                   ->bmul( $self->{'_COUNTER_VALUE_MAX'} )
                                                                                   ->bdiv( 100 )
                                                                                   ->ffround( '-'.$self->{'_COUNTER_VALUE_ROUND'} );
            &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::checkThreshold', 'Converting maxWarningThresholdValue "'.$self->{'_COUNTER_WARNING_THRESHOLD_MIN'}.'" in percentage : "'.$counterWarningThresholdMin.'"' );
            $counterCriticalThresholdMin = $self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'}->copy()
                                                                                     ->bmul( $self->{'_COUNTER_VALUE_MAX'} )
                                                                                     ->bdiv( 100 )
                                                                                     ->ffround( '-'.$self->{'_COUNTER_VALUE_ROUND'} );
            &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::checkThreshold', 'Converting maxCriticalThresholdValue "'.$self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'}.'" in percentage : "'.$counterCriticalThresholdMin.'"' );
          }
        } else {
          croak( 'Undefined counter threshold type "'.$self->{'_COUNTER_THRESHOLD_TYPE'}.'" ( must be "none" are "percentage" )' );
        }
        $self->{'_COUNTER_PERFDATA_MSG'} = "'".$self->{'_COUNTER_PERFDATA_LABEL'}."'=".$self->{'_COUNTER_PERFDATA_VALUE'}.$self->{'_COUNTER_PERFDATA_UNIT'}.';'.
                                           $counterWarningThresholdMin.';'.$counterCriticalThresholdMin.';'.
                                           $self->{'_COUNTER_VALUE_MIN'}.';'.$self->{'_COUNTER_VALUE_MAX'}.';';
      } elsif ( ( ( $self->{'_COUNTER_WARNING_THRESHOLD_MIN'}->is_inf( '-' ) ) or ( $self->{'_COUNTER_WARNING_THRESHOLD_MIN'}->is_zero() ) ) and 
                ( ( $self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'}->is_inf( '-' ) )  or ( $self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'}->is_zero() ) ) and
                ( not( $self->{'_COUNTER_WARNING_THRESHOLD_MAX'}->is_inf( '+' ) ) ) and
                ( not( $self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'}->is_inf( '+' ) ) ) ) {
        # We can defind max if min is -inf or 0 and max is not +inf
        my $counterWarningThresholdMax = 0;
        my $counterCriticalThresholdMax = 0;
        if ( $self->{'_COUNTER_THRESHOLD_TYPE'} eq 'none' ) {
          $counterWarningThresholdMax = $self->{'_COUNTER_WARNING_THRESHOLD_MAX'}->copy();
          $counterCriticalThresholdMax = $self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'}->copy();
        } elsif ( $self->{'_COUNTER_THRESHOLD_TYPE'} eq 'percentage' ) {
          if ( ( $self->{'_COUNTER_VALUE_MAX'}->is_nan() ) or
               ( $self->{'_COUNTER_VALUE_MAX'}->is_inf( '-' ) ) or
               ( $self->{'_COUNTER_VALUE_MAX'}->is_inf( '+' ) ) ) {
            croak( 'No finite value limit defined for counter [ '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ], perhaps you have to set it ...' );
          } else { 
            $counterWarningThresholdMax = $self->{'_COUNTER_WARNING_THRESHOLD_MAX'}->copy()
                                                                                   ->bmul( $self->{'_COUNTER_VALUE_MAX'} )
                                                                                   ->bdiv( 100 )
                                                                                   ->ffround( '-'.$self->{'_COUNTER_VALUE_ROUND'} );
            &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::checkThreshold', 'Converting maxWarningThresholdValue "'.$self->{'_COUNTER_WARNING_THRESHOLD_MAX'}.'" in percentage : "'.$counterWarningThresholdMax.'"' );
            $counterCriticalThresholdMax = $self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'}->copy()
                                                                                     ->bmul( $self->{'_COUNTER_VALUE_MAX'} )
                                                                                     ->bdiv( 100 )
                                                                                     ->ffround( '-'.$self->{'_COUNTER_VALUE_ROUND'} );
            &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::checkThreshold', 'Converting maxCriticalThresholdValue "'.$self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'}.'" in percentage : "'.$counterCriticalThresholdMax.'"' );
          }
        } else {
          croak( 'Undefined counter threshold type "'.$self->{'_COUNTER_THRESHOLD_TYPE'}.'" ( must be "none" are "percentage" )' );
        }
        $self->{'_COUNTER_PERFDATA_MSG'} = "'".$self->{'_COUNTER_PERFDATA_LABEL'}."'=".$self->{'_COUNTER_PERFDATA_VALUE'}.$self->{'_COUNTER_PERFDATA_UNIT'}.';'.
                                           $counterWarningThresholdMax.';'.$counterCriticalThresholdMax.';'.$perfDataLimit;
      } else {
        &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::setPerfData', "We can't defined min and max perf data values in this case." );
        $self->{'_COUNTER_PERFDATA_MSG'} = "'".$self->{'_COUNTER_PERFDATA_LABEL'}."'=".$self->{'_COUNTER_PERFDATA_VALUE'}.$self->{'_COUNTER_PERFDATA_UNIT'}.';;;'.
                                           $perfDataLimit;
      }
    } else {
      &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::setPerfData', "We can't defined min and max perf data values when range type are not the same." );
      $self->{'_COUNTER_PERFDATA_MSG'} = "'".$self->{'_COUNTER_PERFDATA_LABEL'}."'=".$self->{'_COUNTER_PERFDATA_VALUE'}.$self->{'_COUNTER_PERFDATA_UNIT'}.';;;'.
                                         $perfDataLimit;
    }
    &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::setPerfData', $self->{'_COUNTER_PERFDATA_MSG'} );
  } else {
    &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::setPerfData', 'No performance value found.') ;
    &NagiosPlugins::Debug::debug( 6, blessed( $self ).'::setPerfData', $self->{'_COUNTER_PERFDATA_MSG'} );
  } 
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::setPerfData', 'END setPerfData' );
}

# Function setPreviousValue set previous value loaded from data file
sub setPreviousValue() {
  my ( $self, $previousValue ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::setPreviousValue', 'BEGIN setPreviousValue');
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::setPreviousValue', 'setPreviousValue( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.', '.$previousValue.' )');
  $self->{'_COUNTER_VALUE_PREVIOUS'} = Math::BigFloat->new( $previousValue );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::setPreviousValue', 'setPreviousValue( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' , '.$previousValue.' ) = '.$self->{'_COUNTER_VALUE_PREVIOUS'} );
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::setPreviousValue','END setPreviousValue' );
}

# Function setPreviousTimeStamp set previous timestamp loaded from data file
sub setPreviousTimeStamp() {
  my ( $self, $previousTimeStamp ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::setPreviousTimeStamp', 'BEGIN setPreviousTimeStamp' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::setPreviousTimeStamp', 'setPreviousTimeStamp( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.', '.$previousTimeStamp.' )' );
  $self->{'_COUNTER_VALUE_PREVIOUS_TIMESTAMP'} = Math::BigFloat->new( $previousTimeStamp );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::setPreviousTimeStamp', 'setPreviousTimeStamp( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.', '.$previousTimeStamp.' ) = '.$self->{'_COUNTER_VALUE_PREVIOUS_TIMESTAMP'} );
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::setPreviousTimeStamp', 'END setPreviousTimeStamp' );
}

# Function setTimeStamp set current timestamp
sub setTimeStamp() {
  my ( $self, $timeStamp ) = @_;
  &NagiosPlugins::Debug::debug( 9,blessed( $self ).'::setTimeStamp', 'BEGIN setTimeStamp' );
  &NagiosPlugins::Debug::debug( 8,blessed( $self ).'::setTimeStamp', 'setTimeStamp( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.', '.$timeStamp.' )' );
  $self->{'_COUNTER_VALUE_TIMESTAMP'} = Math::BigFloat->new( $timeStamp );
  &NagiosPlugins::Debug::debug( 8,blessed( $self ).'::setTimeStamp', 'setTimeStamp( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.', '.$timeStamp.' ) = '.$self->{'_COUNTER_VALUE_TIMESTAMP'} );
  &NagiosPlugins::Debug::debug( 9,blessed( $self ).'::setTimeStamp', 'END setTimeStamp' );
}

# Function setThreshold set warning or critical threshold for a counter
# [in] $thresholdType : Type of threshold. Must be 'WARNING' or 'CRITICAL'
# [in] $thresholdValue : The threshold's value
sub setThreshold() {
  my ( $self, $thresholdType, $thresholdValue ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::set#Threshold', 'BEGIN setThreshold');
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::setThreshold', 'setThreshold( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.', '.$thresholdType.', '.$thresholdValue.' )' );
  if ( uc( $thresholdType ) =~ /^(WARNING|CRITICAL)$/ ) {
    $self->{'_COUNTER_'.uc ($thresholdType ).'_THRESHOLD'} = $thresholdValue;
  } else {
    &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::setThreshold', 'END setThreshold' );
    croak( 'You must use a correct threshold type ('.$thresholdType.') : "warning" or "critical"' );
  }
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::setThreshold', 'setThreshold( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.', '.$thresholdType.', '.$thresholdValue.' ) = '.$self->{'_COUNTER_'.uc( $thresholdType ).'_THRESHOLD'} );
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::setThreshold', 'END setThreshold' );
}

# Function setLink set a reference on linked counter or undef if no link is given
# $link : a reference to a counter object to link or undef
sub setLink() {
  my ( $self , $link ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::setLink', 'BEGIN setLink' );
  if ( defined ( $link ) ) {
    $self->{'_COUNTER_LINK'} = $link;
    &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::setLink', 'setLink( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ) = '.$self->{'_COUNTER_LINK'} );
  } else {
    $self->{'_COUNTER_LINK'} = undef;
    &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::setLink', 'setLink( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ) = undef' );
  }
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::setLink','END setLink');
}

# Local Id count
my $idCounter = 0;

# This function initialize a counter with defaults values
sub _initialize () {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_initialize', 'BEGIN _initialize' );
  $self->{'_COUNTER_ID'} = $idCounter++;             
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::_initialize', '_initialize( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' )' );
  $self->{'_COUNTER_HIDDEN'}    = '0';
  $self->{'_COUNTER_LINK_NAME'} = undef;
  $self->{'_COUNTER_LINK'}      = undef;
  $self->{'_COUNTER_STATE'} = 'OK';
  $self->{'_COUNTER_MSG'}   = '';
  $self->{'_COUNTER_VALUE'}                    = Math::BigFloat->bnan();
  $self->{'_COUNTER_VALUE_PREVIOUS'}           = Math::BigFloat->bnan();
  $self->{'_COUNTER_VALUE_COMPUTED_FUNCTION'}  = $none;
  $self->{'_COUNTER_VALUE_COMPUTED'}           = Math::BigFloat->bnan();
  $self->{'_COUNTER_VALUE_TIMESTAMP'}          = Math::BigFloat->bnan();
  $self->{'_COUNTER_VALUE_PREVIOUS_TIMESTAMP'} = Math::BigFloat->bnan(); 
  $self->{'_COUNTER_VALUE_LABEL'}              = $self->{'_COUNTER_NAME'}; 
  $self->{'_COUNTER_VALUE_UNIT'}               = '';
  $self->{'_COUNTER_VALUE_LIMIT_MAX'}          = Math::BigFloat->bnan();
  $self->{'_COUNTER_VALUE_LIMIT_MIN'}          = Math::BigFloat->bnan();
  $self->{'_COUNTER_VALUE_MIN'} = Math::BigFloat->new( 0 );
  $self->{'_COUNTER_VALUE_MAX'} = Math::BigFloat->binf( '+' );
  $self->{'_COUNTER_VALUE_ROUND'} = Math::BigFloat->new( 3 );
  $self->{'_COUNTER_VALUE_SCALE'} = Math::BigFloat->new( 1 );
  $self->{'_COUNTER_THRESHOLD_TYPE'} = 'none';
  $self->{'_COUNTER_WARNING_THRESHOLD_MIN'} = Math::BigFloat->new( 0 );
  $self->{'_COUNTER_WARNING_THRESHOLD_MAX'} = Math::BigFloat->binf( '+' );
  $self->{'_COUNTER_WARNING_THRESHOLD_RANGE_TYPE'} = 'inside';
  $self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'} = Math::BigFloat->new( 0 );
  $self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'} = Math::BigFloat->binf( '+' );
  $self->{'_COUNTER_CRITICAL_THRESHOLD_RANGE_TYPE'} = 'inside';
  $self->{'_COUNTER_PERFDATA_LABEL'} = $self->{'_COUNTER_NAME'};
  $self->{'_COUNTER_PERFDATA_VALUE'} = Math::BigFloat->bnan();
  $self->{'_COUNTER_PERFDATA_UNIT'}  = '';
  $self->{'_COUNTER_PERFDATA_MSG'}   = '';
  $self->{'_COUNTER_PERFDATA_COMPUTED_FUNCTION'} = $none;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_initialize', 'END _initialize' );
}

# This function set a counter with user given values
sub _set() {
  my ( $self, $hRef, $selfKey, $hKey, $isRequired ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_set', 'BEGIN _set' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::_set', '_set( '.$self.', '.$hRef.', '.$selfKey.','.$hKey.', '.$isRequired.' )');
  if ( defined( $hRef->{$hKey} ) ) {
    &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::_set','_set( '.$self.', '.$hRef.', '.$selfKey.', '.$hKey.', '.$isRequired.' ) = '.$hRef->{$hKey} );
    if ( $hKey =~ /^(value|valueMin|valueLimitMax|valueMin|valueMax|valueScale|valueRound|perfDataValue|perfDataMin|perfDataMax|warningThreshold|criticalThreshold)$/ ) {
      $self->{$selfKey} = Math::BigFloat->new( $hRef->{$hKey} );
    } else {
      $self->{$selfKey} = $hRef->{$hKey}; 
    }
  } else {
    if ( $isRequired ) {
      &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_set', 'END _set' );
      croak( 'You must defined a "'.$hKey.'" for this counter ( '.$self->{'_COUNTER_NAME'}.' ).');
    }
  }
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_set', 'END _set' );
}

# This function check if an counter attribute can be set and is set or not
sub _validate() {
  my ( $self, $hRef ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_validate', 'BEGIN _validate' );
  foreach my $hKey ( keys( %{$hRef} ) ) {
    &NagiosPlugins::Debug::debug(8,blessed( $self ).'::_validate','_validate( '.$hKey.' )');
    if ( $hKey !~ /^(name|value|label|valueScale|valueUnit|valueMin|valueLimitMax|valueMax|valueMin|valueRound|thresholdType|warningThreshold|criticalThreshold|valueComputedFunction|perfDataComputedFunction|perfDataValue|perfDataLabel|perfDataUnit|perfDataMin|perfDataMax|hidden|linkName)$/ ) {
      &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_validate', 'END _validate' );
      croak( 'Undefined counter propertie "'.$hKey.'".' );
    } else {
      if ( not( defined( $hRef->{$hKey} ) ) ) {
        &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_validate', 'END _validate' );
        croak( 'You provide an undefined value "'.$hKey.'" for this counter ( '.$self->{'_COUNTER_NAME'}.' ).');
      }
    } 
  }
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_validate', 'END _validate' );
}

# This function create a counter
sub new {
  my ( $class, $argsHRef ) = @_;
  $class = ref( $class ) || $class;
  my $self = {};
  bless( $self, $class );
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::new', 'BEGIN new' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::new', 'new('.$class.')' );
  $self->_set( $argsHRef, '_COUNTER_NAME', 'name' ,1 );
  $self->_validate( $argsHRef );
  $self->_initialize();
  $self->_set( $argsHRef,'_COUNTER_VALUE', 'value', 1 );
  $self->_set( $argsHRef,'_COUNTER_HIDDEN', 'hidden', 0 );
  $self->_set( $argsHRef,'_COUNTER_LINK_NAME', 'linkName', 0 );
  $self->_set( $argsHRef,'_COUNTER_VALUE_LABEL', 'label', 0 );
  $self->_set( $argsHRef,'_COUNTER_VALUE_SCALE', 'valueScale', 0 );
  $self->_set( $argsHRef,'_COUNTER_VALUE_UNIT', 'valueUnit', 0 );
  $self->_set( $argsHRef,'_COUNTER_VALUE_MIN', 'valueMin', 0 );
  $self->_set( $argsHRef,'_COUNTER_VALUE_LIMIT_MAX', 'valueLimitMax', 0 );
  $self->_set( $argsHRef,'_COUNTER_VALUE_MIN', 'valueMin', 0 );
  $self->_set( $argsHRef,'_COUNTER_VALUE_MAX', 'valueMax', 0 );
  $self->_set( $argsHRef,'_COUNTER_VALUE_ROUND', 'valueRound', 0 );
  $self->_set( $argsHRef,'_COUNTER_THRESHOLD_TYPE', 'thresholdType', 0 );
  $self->_set( $argsHRef,'_COUNTER_WARNING_THRESHOLD', 'warningThreshold', 0 );
  $self->_set( $argsHRef,'_COUNTER_CRITICAL_THRESHOLD', 'criticalThreshold', 0 );
  $self->_set( $argsHRef,'_COUNTER_VALUE_COMPUTED_FUNCTION', 'valueComputedFunction', 0 );
  $self->_set( $argsHRef,'_COUNTER_PERFDATA_COMPUTED_FUNCTION', 'perfDataComputedFunction', 0 );
  $self->_set( $argsHRef,'_COUNTER_PERFDATA_VALUE', 'perfDataValue', 0 );
  $self->_set( $argsHRef,'_COUNTER_PERFDATA_LABEL', 'perfDataLabel', 0 );
  $self->_set( $argsHRef,'_COUNTER_PERFDATA_UNIT', 'perfDataUnit', 0 );
  $self->_set( $argsHRef,'_COUNTER_PERFDATA_MIN', 'perfDataMin', 0 );
  $self->_set( $argsHRef,'_COUNTER_PERFDATA_MAX', 'perfDataMax', 0 );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::new', 'new( '.$class.' ) = '.$self );
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::new', 'END new');
  return $self;
}

# This function dump a counter
sub dump() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::dump', 'BEGIN dump');
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', 'dump( '.$self->{'_COUNTER_ID'}.', '.$self->{'_COUNTER_NAME'}.' ) = { ' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_HIDDEN => '.$self->{'_COUNTER_HIDDEN'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_LINK => '.$self->{'_COUNTER_LINK'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_LINK_NAME => '.$self->{'_COUNTER_LINK_NAME'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_MSG => '.$self->{'_COUNTER_MSG'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_STATE => '.$self->{'_COUNTER_STATE'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_VALUE => '.$self->{'_COUNTER_VALUE'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_VALUE_PREVIOUS => '.$self->{'_COUNTER_VALUE_PREVIOUS'}.'}' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_VALUE_COMPUTED => '.$self->{'_COUNTER_VALUE_COMPUTED'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_VALUE_COMPUTED_FUNCTION => '.$self->{'_COUNTER_VALUE_COMPUTED_FUNCTION'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_VALUE_LABEL => '.$self->{'_COUNTER_VALUE_LABEL'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_VALUE_TIMESTAMP => '.$self->{'_COUNTER_VALUE_TIMESTAMP'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_VALUE_PREVIOUS_TIMESTAMP => '.$self->{'_COUNTER_VALUE_PREVIOUS_TIMESTAMP'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_VALUE_MIN => '.$self->{'_COUNTER_VALUE_MIN'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_VALUE_MAX => '.$self->{'_COUNTER_VALUE_MAX'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_VALUE_LIMIT_MIN => '.$self->{'_COUNTER_VALUE_LIMIT_MIN'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_VALUE_LIMIT_MAX => '.$self->{'_COUNTER_VALUE_LIMIT_MAX'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_VALUE_MIN => '.$self->{'_COUNTER_VALUE_MIN'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_VALUE_UNIT => '.$self->{'_COUNTER_VALUE_UNIT'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_VALUE_ROUND => '.$self->{'_COUNTER_VALUE_ROUND'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_VALUE_SCALE => '.$self->{'_COUNTER_VALUE_SCALE'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_THRESHOLD_TYPE => '.$self->{'_COUNTER_THRESHOLD_TYPE'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_WARNING_THRESHOLD => '.$self->{'_COUNTER_WARNING_THRESHOLD'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_WARNING_THRESHOLD_MAX => '.$self->{'_COUNTER_WARNING_THRESHOLD_MAX'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_WARNING_THRESHOLD_MIN => '.$self->{'_COUNTER_WARNING_THRESHOLD_MIN'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_WARNING_THRESHOLD_RANGE_TYPE => '.$self->{'_COUNTER_WARNING_THRESHOLD_RANGE_TYPE'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_CRITICAL_THRESHOLD => '.$self->{'_COUNTER_CRITICAL_THRESHOLD'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_CRITICAL_THRESHOLD_MAX => '.$self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_CRITICAL_THRESHOLD_MIN => '.$self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_CRITICAL_THRESHOLD_RANGE_TYPE => '.$self->{'_COUNTER_CRITICAL_THRESHOLD_RANGE_TYPE'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_PERFDATA_COMPUTED_FUNCTION => '.$self->{'_COUNTER_PERFDATA_COMPUTED_FUNCTION'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_PERFDATA_LABEL => '.$self->{'_COUNTER_PERFDATA_LABEL'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_PERFDATA_MSG => '.$self->{'_COUNTER_PERFDATA_MSG'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_PERFDATA_UNIT => '.$self->{'_COUNTER_PERFDATA_UNIT'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_PERFDATA_MIN => '.$self->{'_COUNTER_PERFDATA_MIN'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_PERFDATA_MAX => '.$self->{'_COUNTER_PERFDATA_MAX'}.',' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '    _COUNTER_PERFDATA_VALUE => '.$self->{'_COUNTER_PERFDATA_VALUE'} );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::dump', '}' );
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::dump', 'END dump' );
}

1;
__END__

=head1 NAME

 NagiosPlugins::Counters - Provides counters management for nagios plugins devel.

=head1 SYNOPSIS
 
 This class provides usefull functions to manipulate counters. A counter is defined as a hash ref with predefined values :

 my $counterRef = {
                    'name' => "<counter name>"                    # Name of the counter (must be defined)
                    'value' => "<counter value>"                  # Value of the counter use for computing and displaying nagios message (must be defined)
                    'hidden' => "<0|1>"                         # If a counter is hidden, it is not displayed in nagios message. By default set to 0.
                    'link-name' => "<linked counter name>"        # The name of the linked counter. A linked counter has to be defined for computing average. 
                                                                  # Empty by default.
                    'label'     => "<Counter label>"               # The label to display before value in nagios message. By default set to counter's name.
                    'valueScale' => <scale>                       # Use to adjust scale of a value. For example if your counter is in Kb and you want it in
                                                                  # bits, you can set valueScate to 1024. By default, valueScale is set to 1.
                    'valueUnit' => 
tt
  $self->_set( $argsHRef,'_COUNTER_VALUE_LABEL', 'label', 0 );
  $self->_set( $argsHRef,'_COUNTER_VALUE_SCALE', 'valueScale', 0 );
  $self->_set( $argsHRef,'_COUNTER_VALUE_UNIT', 'valueUnit', 0 );
  $self->_set( $argsHRef,'_COUNTER_VALUE_MIN', 'valueMin', 0 );
  $self->_set( $argsHRef,'_COUNTER_VALUE_LIMIT_MAX', 'valueLimitMax', 0 );
  $self->_set( $argsHRef,'_COUNTER_VALUE_MIN', 'valueMin', 0 );
  $self->_set( $argsHRef,'_COUNTER_VALUE_MAX', 'valueMax', 0 );
  $self->_set( $argsHRef,'_COUNTER_VALUE_ROUND', 'valueRound', 0 );
  $self->_set( $argsHRef,'_COUNTER_THRESHOLD_TYPE', 'thresholdType', 0 );
  $self->_set( $argsHRef,'_COUNTER_WARNING_THRESHOLD', 'warningThreshold', 0 );
  $self->_set( $argsHRef,'_COUNTER_CRITICAL_THRESHOLD', 'criticalThreshold', 0 );
  $self->_set( $argsHRef,'_COUNTER_VALUE_COMPUTED_FUNCTION', 'valueComputedFunction', 0 );
  $self->_set( $argsHRef,'_COUNTER_PERFDATA_COMPUTED_FUNCTION', 'perfDataComputedFunction', 0 );
  $self->_set( $argsHRef,'_COUNTER_PERFDATA_VALUE', 'perfDataValue', 0 );
  $self->_set( $argsHRef,'_COUNTER_PERFDATA_LABEL', 'perfDataLabel', 0 );
  $self->_set( $argsHRef,'_COUNTER_PERFDATA_UNIT', 'perfDataUnit', 0 );
  $self->_set( $argsHRef,'_COUNTER_PERFDATA_MIN', 'perfDataMin', 0 );
  $self->_set( $argsHRef,'_COUNTER_PERFDATA_MAX', 'perfDataMax', 0 );
  $self->{'_COUNTER_STATE'} = 'OK';
  $self->{'_COUNTER_MSG'}   = '';
  $self->{'_COUNTER_VALUE_COMPUTED_FUNCTION'}  = $none;
  $self->{'_COUNTER_VALUE_COMPUTED'}           = Math::BigFloat->bnan();
  $self->{'_COUNTER_VALUE_PREVIOUS'}           = Math::BigFloat->bnan();
  $self->{'_COUNTER_VALUE_TIMESTAMP'}          = Math::BigFloat->bnan();
  $self->{'_COUNTER_VALUE_PREVIOUS_TIMESTAMP'} = Math::BigFloat->bnan();
  $self->{'_COUNTER_VALUE_LABEL'}              = $self->{'_COUNTER_NAME'};
  $self->{'_COUNTER_VALUE_UNIT'}               = '';
  $self->{'_COUNTER_VALUE_LIMIT_MAX'}                = Math::BigFloat->bnan();
  $self->{'_COUNTER_VALUE_MIN'}                = Math::BigFloat->bnan();
  $self->{'_COUNTER_VALUE_MIN'}          = Math::BigFloat->new( 0 );
  $self->{'_COUNTER_VALUE_MAX'}          = Math::BigFloat->binf( '+' );
  $self->{'_COUNTER_VALUE_ROUND'}              = Math::BigFloat->new( 3 );
  $self->{'_COUNTER_VALUE_SCALE'}              = Math::BigFloat->new( 1 );
  $self->{'_COUNTER_THRESHOLD_TYPE'}               = 'none';
  $self->{'_COUNTER_WARNING_THRESHOLD_MIN'}        = Math::BigFloat->new( 0 );
  $self->{'_COUNTER_WARNING_THRESHOLD_MAX'}        = Math::BigFloat->binf( '+' );
  $self->{'_COUNTER_WARNING_THRESHOLD_RANGE_TYPE'} = 'inside';
  $self->{'_COUNTER_CRITICAL_THRESHOLD_MIN'}        = Math::BigFloat->new( 0 );
  $self->{'_COUNTER_CRITICAL_THRESHOLD_MAX'}        = Math::BigFloat->binf( '+' );
  $self->{'_COUNTER_CRITICAL_THRESHOLD_RANGE_TYPE'} = 'inside';
  $self->{'_COUNTER_PERFDATA_COMPUTED_FUNCTION'} = $none;
  $self->{'_COUNTER_PERFDATA_LABEL'} = $self->{'_COUNTER_NAME'};
  $self->{'_COUNTER_PERFDATA_VALUE'} = Math::BigFloat->bnan();
  $self->{'_COUNTER_PERFDATA_UNIT'}  = '';
  $self->{'_COUNTER_PERFDATA_MSG'}   = '';


 
 # To create a new counter :
 my $counter = NagiosPlugins::Counters::new( )


 sub compute() {
our $none = sub {
our $delta = sub {
our $average = sub {
our $rate = sub {
sub convertToHumanReadable() {
sub parseThreshold () {
sub checkThreshold () {
sub isHidden() {
sub getId() {
sub getLinkName() {
sub getPerfDataMsg() {
sub getMsg() {
sub getState() {
sub getName() {
sub getValue() {
sub setPerfData() {
sub setPreviousValue() {
sub setPreviousTimeStamp() {
sub setTimeStamp() {
sub setThreshold() {
sub setLink() {
sub _initialize () {
sub _set() {
sub _validate() {
sub new {
sub dump() {


 #  Global variable for setting debugging level
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


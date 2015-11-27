package NagiosPlugins::Objects;

use warnings;
use strict;
use Carp;
use NagiosPlugins::Counters;
use Math::BigFloat;
use Scalar::Util 'blessed';
use FindBin;
use File::Basename;
use vars qw($PROGNAME);
use lib "$FindBin::Bin";
use lib "/usr/lib/nagios/plugins";
use utils qw (%ERRORS &print_revision);

our $VERSION = '1.00';

sub _initialize () {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug(9,blessed($self).'::_initialize','BEGIN _initialize');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::_initialize','_initialize('.$self->{'_OBJECT_NAME'}.')');
  $self->{'_OBJECT_COUNTERS'} = undef;
  $self->{'_OBJECT_MSG'}      = [];
  $self->{'_OBJECT_STATE'}    = [];
  $self->{'_OBJECT_EXPAND_THRESHOLD'}    = 0;
  $self->{'_OBJECT_PERFDATA_MSG'}                = [];
  $self->{'_OBJECT_PREVIOUS_DATA_FOLDER'}             = '/tmp';
  $self->{'_OBJECT_PREVIOUS_DATA_FILE'}               = basename($0).'_'.$self->{'_OBJECT_NAME'}.'.dat';
  $self->{'_OBJECT_DATA_TIMESTAMP'}          = Math::BigFloat->new(time());
  $self->{'_OBJECT_DATA_PREVIOUS_TIMESTAMP'} = 0;
  &NagiosPlugins::Debug::debug(9,blessed($self).'::_initialize','END _initialize');
}

sub _set() {
  my ( $self, $hRef, $selfKey, $hKey, $isRequired ) = @_;
  &NagiosPlugins::Debug::debug(9,blessed($self).'::_set','BEGIN _set');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::_set','_set(self,hRef,'.$selfKey.','.$hKey.','.$isRequired.')');
  if ( defined( $hRef->{$hKey} ) ) {
    &NagiosPlugins::Debug::debug(8,blessed($self).'::_set','_set(self,hRef,'.$selfKey.','.$hKey.','.$isRequired.')='.$hRef->{$hKey});
    if ( $hKey =~ /^counters$/ ) {
      my $countersArrayRef = $hRef->{$hKey};
      for ( my $counterId=0 ; $counterId < scalar(@{$countersArrayRef}) ; $counterId++ ) {
        if ( defined( @{$countersArrayRef}[$counterId]->{'name'} ) ) {
          my $counter = NagiosPlugins::Counters::->new(@{$countersArrayRef}[$counterId]);
          $counter->setTimeStamp($self->{'_OBJECT_DATA_TIMESTAMP'});
          push(@{$self->{$selfKey}},$counter);
        } else {
          croak( 'You must provide a counter name for counter id "'.$counterId.'"' );
        }
      }
    } elsif ( $hKey =~ /^warningThresholds|criticalThresholds$/ ) {
      my $thresholdType = $hKey;
      $thresholdType =~ s/Thresholds//;
      my @thresholdsArray = split( ',',$hRef->{$hKey} );
      my $countersArrayCount = scalar( @{$self->{'_OBJECT_COUNTERS'}} );
      my $thresholdArrayCount = scalar( @thresholdsArray );
      my $thresholdCount = 0;
      &NagiosPlugins::Debug::debug(8,blessed($self).'::_set','Found "'.$thresholdArrayCount.'" threshold(s) for "'.$countersArrayCount.'" counter(s).');
      my $missedCounters = '';
      my $totalDisplayedCounters = 0;
      my $thresholdId = 0;
      for( my $counterId = 0 ; $counterId < $countersArrayCount ; $counterId++ ) {
        if ( @{$self->{'_OBJECT_COUNTERS'}}[$counterId]->isHidden() ) {
          &NagiosPlugins::Debug::debug(8,blessed($self).'::_set','Hidden counter "'.@{$self->{'_OBJECT_COUNTERS'}}[$counterId]->getName().'".We do not have to set threshold.');
        } else {
          if ( defined ( $thresholdsArray[$thresholdId] ) ) {
            &NagiosPlugins::Debug::debug(8,blessed($self).'::_set','Setting '.$thresholdType.' threshold for counter "'.@{$self->{'_OBJECT_COUNTERS'}}[$counterId]->getName().'" to "'.$thresholdsArray[$thresholdId].'" ...');
            @{$self->{'_OBJECT_COUNTERS'}}[$counterId]->setThreshold($thresholdType,$thresholdsArray[$thresholdId]);
            if ( not( $self->{'_OBJECT_EXPAND_THRESHOLD'} ) ) {
              $thresholdId ++;
            }
            $thresholdCount++;
          } else {
            $missedCounters.= ','.@{$self->{'_OBJECT_COUNTERS'}}[$counterId]->getName();
          }
          $totalDisplayedCounters++;
        }
      }
      $missedCounters =~ s/^,//;
      if ( $totalDisplayedCounters > $thresholdCount ) {
        push( @{$self->{'_OBJECT_STATE'}}, 'UNKNOWN' );
        push( @{$self->{'_OBJECT_MSG'}}, 'You must provide "'.$totalDisplayedCounters.'" '.$thresholdType.' thresholds for object "'.$self->{'_OBJECT_NAME'}.'". Missed counters : '.$missedCounters.'.' );
      }
    } else {
      $self->{$selfKey} = $hRef->{$hKey}; 
    }
  } else {
    if ( $isRequired ) {
      &NagiosPlugins::Debug::debug(9,blessed($self).'::_set','END _set');
      croak( 'You must defined a "'.$hKey.'" for this object ('.$self->{'_OBJECT_NAME'}.').');
    }
  }
  &NagiosPlugins::Debug::debug(9,blessed($self).'::_set','END _set');
}

sub _validate() {
  my ( $self, $hRef ) = @_;
  &NagiosPlugins::Debug::debug(9,blessed($self).'::_validate','BEGIN _validate');
  foreach my $hKey ( keys( %{$hRef} ) ) {
    if ( $hKey !~ /^name|counters|warningThresholds|criticalThresholds|expandThreshold|dataFolder|dataFile$/ ) {
      &NagiosPlugins::Debug::debug(9,blessed($self).'::_validate','END _validate');
      croak('Undefined object propertie "'.$hKey.'"');
    }
  }
  &NagiosPlugins::Debug::debug(9,blessed($self).'::_validate','END _validate');
}


sub _saveObject() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug(9,blessed($self).'::_saveObject','BEGIN _saveObject');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::_saveObject','_saveObject('.$self->{'_OBJECT_NAME'}.')');
  my $dataFile = $self->{'_OBJECT_PREVIOUS_DATA_FOLDER'}.'/'.$self->{'_OBJECT_PREVIOUS_DATA_FILE'};
  if (open(my $fhPerfDataFile,'>',"$dataFile")) {
    &NagiosPlugins::Debug::debug(6,blessed($self).'::_saveObject','Writing data info in "'.$dataFile.'" ...');
    print $fhPerfDataFile '-#timestamp='.$self->{'_OBJECT_DATA_TIMESTAMP'}."\n";
    &NagiosPlugins::Debug::debug(5,blessed($self).'::_saveObject','Object timestamp "(-)[timestamp]" => "'.$self->{'_OBJECT_DATA_TIMESTAMP'}.'" : [SAVED]');
    my $countersArrayRef = $self->{'_OBJECT_COUNTERS'};
    my $countersArrayCount = scalar(@{$countersArrayRef});
    &NagiosPlugins::Debug::debug(6,blessed($self).'::_saveObject','Found '.$countersArrayCount.' counter(s) to save ...');
    for ( my $counterId=0 ; $counterId < scalar(@{$countersArrayRef}) ; $counterId++ ) {
      my $counterName = @{$countersArrayRef}[$counterId]->getName();
      my $counterValue = @{$countersArrayRef}[$counterId]->getValue();
      print $fhPerfDataFile $counterId.'#'.$counterName.'='.$counterValue."\n";
      &NagiosPlugins::Debug::debug(5,blessed($self).'::_saveObject','Counter ('.$counterId.')['.$counterName.']" => "'.$counterValue.'" : [SAVED]');
    }
    close($fhPerfDataFile);
  } else {
    push( @{$self->{'_OBJECT_STATE'}}, 'UNKNOWN' );
    push( @{$self->{'_OBJECT_MSG'}}, 'Unable to open file "'.$dataFile.'" ('.$!.').' );
    &NagiosPlugins::Debug::debug(9,blessed($self).'::_saveObject','END _saveObject');
  }
  &NagiosPlugins::Debug::debug(9,blessed($self).'::_saveObject','END _saveObject');
}
sub _getCounter() {
  my ( $self , $counterId , $counterName ) = @_;
  &NagiosPlugins::Debug::debug(9,blessed($self).'::_getCounter','BEGIN _getCounter');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::_getCounter','_getCounter('.$self->{'_OBJECT_NAME'}.','.$counterId.','.$counterName.')');
  my $countersArrayRef = $self->{'_OBJECT_COUNTERS'};
  my $countersArrayCount = scalar(@{$countersArrayRef});
  if ( ( $counterId >= 0 ) and ( $counterId < $countersArrayCount ) ) {
    my $currentCounterRef = @{$countersArrayRef}[$counterId];
    if ( $currentCounterRef->getName() eq $counterName ) {
      &NagiosPlugins::Debug::debug(8,blessed($self).'::_getcounter','_getCounter('.$self->{'_OBJECT_NAME'}.','.$counterId.','.$counterName.')=('.$currentCounterRef->getId().','.$currentCounterRef->getName().')');
      &NagiosPlugins::Debug::debug(9,blessed($self).'::_getCounter','END _getCounter');
      return( $currentCounterRef ); 
    } else {
      &NagiosPlugins::Debug::debug(9,blessed($self).'::_getCounter','Unable to find counter name "'.$counterName.'" with id "'.$counterId.'" for Object "'.$self->{'_OBJECT_NAME'}.'"');
      &NagiosPlugins::Debug::debug(9,blessed($self).'::_getCounter','END _getCounter');
      return( undef );
    }
  } else {
    &NagiosPlugins::Debug::debug(9,blessed($self).'::_getCounter','Unable to find counter id "'.$counterId.'" for Object "'.$self->{'_OBJECT_NAME'}.'"');
    &NagiosPlugins::Debug::debug(9,blessed($self).'::_getCounter','END _getCounter');
    return( undef );
  }
}

sub _getCounterByName() {
  my ( $self , $counterName ) = @_;
  &NagiosPlugins::Debug::debug(9,blessed($self).'::_getCounterByName','BEGIN _getCounter');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::_getcounter','_getCounterByName('.$self->{'_OBJECT_NAME'}.','.$counterName.')');
  my $countersArrayRef = $self->{'_OBJECT_COUNTERS'};
  my $countersArrayCount = scalar(@{$countersArrayRef});
  for ( my $counterId = 0 ; $counterId < $countersArrayCount ; $counterId++ ) {
    if ( @{$countersArrayRef}[$counterId]->getName() eq $counterName ) {
      &NagiosPlugins::Debug::debug(8,blessed($self).'::_getCounterByName','_getCounterByName('.$self->{'_OBJECT_NAME'}.','.$counterName.')=('.@{$countersArrayRef}[$counterId]->getId().','.@{$countersArrayRef}[$counterId].')');
      &NagiosPlugins::Debug::debug(9,blessed($self).'::_getCounterByName','END _getCounter');
      return( @{$countersArrayRef}[$counterId] ); 
    }
  }
 
  &NagiosPlugins::Debug::debug(9,blessed($self).'::_getCounterByName','Unable to find counter name "'.$counterName.'" for Object "'.$self->{'_OBJECT_NAME'}.'"');
  &NagiosPlugins::Debug::debug(9,blessed($self).'::_getCounterByName','END _getCounter');
  return( undef );
}

sub _loadObject() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug(9,blessed($self).'::_loadObject','BEGIN _loadObject');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::_loadObject','_loadObject('.$self->{'_OBJECT_NAME'}.')');
  my $dataFile = $self->{'_OBJECT_PREVIOUS_DATA_FOLDER'}.'/'.$self->{'_OBJECT_PREVIOUS_DATA_FILE'};
  if (open(my $fhPerfDataFile,'<',"$dataFile")) {
    my $isTimeStampDefined = 0;
    &NagiosPlugins::Debug::debug(6,blessed($self).'::_loadObject','Loading previous data info from "'.$dataFile.'" ...');
    while (defined (my $line = <$fhPerfDataFile>)) {
      chomp ($line);
      if ( "$line" =~ /^([^#]+)#([^=]+)=([-.0-9]+)$/) {
        my $objectId = $1;
        my $objectName = $2;
        my $objectValue = $3;
        if ( ( "$objectName" eq 'timestamp' ) and ( "$objectId" eq '-' ) ) {
          $self->{'_OBJECT_DATA_PREVIOUS_TIMESTAMP'} = Math::BigFloat->new($objectValue);
          $isTimeStampDefined = 1;
        } else {
          my $currentCounter = $self->_getCounter($objectId,$objectName);
          if ( defined( $currentCounter ) ) {
            $currentCounter->setPreviousTimeStamp($self->{'_OBJECT_DATA_PREVIOUS_TIMESTAMP'});
            $currentCounter->setPreviousValue($objectValue);
          } else {
            push( @{$self->{'_OBJECT_STATE'}}, 'UNKNOWN' );
            push( @{$self->{'_OBJECT_MSG'}}, 'Unable to read "'.$dataFile.' : " (Counter "'.$objectName.'" with id "'.$objectId.'" not found)' );
          }
        }
      } else {
        push( @{$self->{'_OBJECT_STATE'}}, 'UNKNOWN' );
        push( @{$self->{'_OBJECT_MSG'}}, 'Unable to read "'.$dataFile.'" : (Bad line "'.$line.'")' );
      }
    }
    close($fhPerfDataFile);
    if ( not( $isTimeStampDefined ) ) {
      push( @{$self->{'_OBJECT_STATE'}}, 'UNKNOWN' );
      push( @{$self->{'_OBJECT_MSG'}}, 'No timestamp found in previous data file "'.$dataFile.'"' );
    }
  } else {
    &NagiosPlugins::Debug::debug(1,blessed($self).'::_loadObject','Unable to open file "'.$dataFile.'" ('.$!.'), maybe it is first execution time ...');
  }
  &NagiosPlugins::Debug::debug(9,blessed($self).'::_loadObject','END _loadObject');
}

sub setPerfDataMsg() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug(9,blessed($self).'::setPerfDataMsg','BEGIN setPerfDataMsg');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::setPerfDataMsg','setPerfDataMsg('.$self->{'_OBJECT_NAME'}.')');
  my $countersArrayRef = $self->{'_OBJECT_COUNTERS'};
  my $countersArrayCount = scalar(@{$countersArrayRef});
  &NagiosPlugins::Debug::debug(6,blessed($self).'::setPerfDataMsg','Found '.$countersArrayCount.' counter(s) with perf data to parse ...');
  for ( my $counterId=0 ; $counterId < scalar(@{$countersArrayRef}) ; $counterId++ ) {
    if ( @{$countersArrayRef}[$counterId]->isHidden() ) {
      &NagiosPlugins::Debug::debug(6,blessed($self).'::setPerfDataMsg','Hidden counter "'.@{$countersArrayRef}[$counterId]->getName().'". Nothing to set');
    } else {
      @{$countersArrayRef}[$counterId]->setPerfData();
      push( @{$self->{'_OBJECT_PERFDATA_MSG'}}, @{$countersArrayRef}[$counterId]->getPerfDataMsg() );
    }
  }
  &NagiosPlugins::Debug::debug(9,blessed($self).'::setPerfDataMsg','END setPerfDataMsg');
}




sub parseThresholds() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug(9,blessed($self).'::parseThresholds','BEGIN parseThresholds');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::parseThresholds','parseThresholds('.$self->{'_OBJECT_NAME'}.')');
  my $countersArrayRef = $self->{'_OBJECT_COUNTERS'};
  my $countersArrayCount = scalar(@{$countersArrayRef});
  &NagiosPlugins::Debug::debug(6,blessed($self).'::parseThresholds','Found '.$countersArrayCount.' counter(s) with thresholds to parse ...');
  for ( my $counterId=0 ; $counterId < scalar(@{$countersArrayRef}) ; $counterId++ ) {
    if ( @{$countersArrayRef}[$counterId]->isHidden() ) {
      &NagiosPlugins::Debug::debug(6,blessed($self).'::parseThresholds','Hidden counter "'.@{$countersArrayRef}[$counterId]->getName().'". Nothing to parse');
    } else {
      @{$countersArrayRef}[$counterId]->parseThreshold();
      push( @{$self->{'_OBJECT_MSG'}}, @{$countersArrayRef}[$counterId]->getMsg() );
      push( @{$self->{'_OBJECT_STATE'}}, @{$countersArrayRef}[$counterId]->getState() );
    }
  }
  &NagiosPlugins::Debug::debug(9,blessed($self).'::parseThresholds','END parseThresholds');
}

sub getPerfDataMsg() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug(9,blessed($self).'::getPerfDataMsg','BEGIN getPerfDataMsg');
  my $objectPerfDataMsg = '';
  my $objectPerfDataMsgList = {};
  for ( my $perfDataCpt = 0; $perfDataCpt < scalar( @{$self->{'_OBJECT_PERFDATA_MSG'}} ); $perfDataCpt++ ) {
    &NagiosPlugins::Debug::debug( 8, blessed($self).'::getPerfDataMsg', 'Found perfdata message "'.@{$self->{'_OBJECT_PERFDATA_MSG'}}[$perfDataCpt].'")' );
    $objectPerfDataMsg .= @{$self->{'_OBJECT_PERFDATA_MSG'}}[$perfDataCpt].' ';
  }
  $objectPerfDataMsg =~ s/ $//;
  &NagiosPlugins::Debug::debug( 8, blessed($self).'::getPerfDataMsg', 'getPerfDataMsg('.$self->{'_OBJECT_NAME'}.')='.$objectPerfDataMsg );
  &NagiosPlugins::Debug::debug( 9, blessed($self).'::getPerfDataMsg', 'END getPerfDataMsg');
  return( $objectPerfDataMsg );
}

sub getMsg() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed($self).'::getMsg', 'BEGIN getMsg');
  my $objectMsg = '';
  my $objectMsgList = {};
  for ( my $stateCpt = 0; $stateCpt < scalar( @{$self->{'_OBJECT_STATE'}} ); $stateCpt++ ) {
    &NagiosPlugins::Debug::debug( 8, blessed($self).'::getMsg', 'Found state "'.@{$self->{'_OBJECT_STATE'}}[$stateCpt].'" with message "'.@{$self->{'_OBJECT_MSG'}}[$stateCpt].'")' );
    if ( ( @{$self->{'_OBJECT_MSG'}}[$stateCpt] eq '' ) and ( $ERRORS{@{$self->{'_OBJECT_STATE'}}[$stateCpt]} == 0  ) ) {
      &NagiosPlugins::Debug::debug( 8, blessed($self).'::getMsg', 'Ignoring null message in OK state' );
    } else {
      if ( defined( $objectMsgList->{@{$self->{'_OBJECT_MSG'}}[$stateCpt]} ) ) {
        &NagiosPlugins::Debug::debug( 8, blessed($self).'::getMsg', 'Ignoring duplicate message "'.@{$self->{'_OBJECT_MSG'}}[$stateCpt].'"' );
      } else {  
        $objectMsg .= @{$self->{'_OBJECT_MSG'}}[$stateCpt].' ';
        $objectMsgList->{@{$self->{'_OBJECT_MSG'}}[$stateCpt]} = @{$self->{'_OBJECT_MSG'}}[$stateCpt];
      }
    }
  }
  $objectMsg =~ s/ $//;
  &NagiosPlugins::Debug::debug( 8, blessed($self).'::getMsg', 'getMsg('.$self->{'_OBJECT_NAME'}.')='.$objectMsg );
  &NagiosPlugins::Debug::debug( 9, blessed($self).'::getMsg', 'END getMsg');
  return( $objectMsg );
}

sub getState() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed($self).'::getState', 'BEGIN getState' );
  my $highestState = 'OK';
  for ( my $stateCpt = 0; $stateCpt < scalar( @{$self->{'_OBJECT_STATE'}} ); $stateCpt++ ) {
    &NagiosPlugins::Debug::debug( 8, blessed($self).'::getState', 'Found state "'.@{$self->{'_OBJECT_STATE'}}[$stateCpt].'"['.$ERRORS{@{$self->{'_OBJECT_STATE'}}[$stateCpt]}.'] (Current state : "'.$highestState.'"['.$ERRORS{$highestState}.'])' );
    if ( $ERRORS{@{$self->{'_OBJECT_STATE'}}[$stateCpt]} > $ERRORS{$highestState} ) {
      $highestState = @{$self->{'_OBJECT_STATE'}}[$stateCpt];
    }
  }
  &NagiosPlugins::Debug::debug( 8, blessed($self).'::getState', 'getState('.$self->{'_OBJECT_NAME'}.')='.$highestState );
  &NagiosPlugins::Debug::debug( 9, blessed($self).'::getState', 'END getState' );
  return( $highestState );
}

sub computeData() {
  my ( $self, $needPreviousData ) = @_;
  &NagiosPlugins::Debug::debug(9,blessed($self).'::computeData','BEGIN computeData');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::computeData','computeData('.$self->{'_OBJECT_NAME'}.','.$needPreviousData.')');
  if ( $needPreviousData ) {
    $self->_loadObject();
    $self->_saveObject();
  }
  my $countersArrayRef = $self->{'_OBJECT_COUNTERS'};
  my $countersArrayCount = scalar(@{$countersArrayRef});
  &NagiosPlugins::Debug::debug(6,blessed($self).'::computeData','Found '.$countersArrayCount.' counter(s) to compute ...');
  for ( my $counterId=0 ; $counterId < scalar(@{$countersArrayRef}) ; $counterId++ ) {
    if ( @{$countersArrayRef}[$counterId]->isHidden() ) {
      &NagiosPlugins::Debug::debug(6,blessed($self).'::computeData','Hidden counter '.@{$countersArrayRef}[$counterId]->getName().'. No compute.');
    } else {
      my $linkName = @{$countersArrayRef}[$counterId]->getLinkName();
      if ( defined( $linkName ) ) {
        @{$countersArrayRef}[$counterId]->setLink( $self->_getCounterByName( $linkName ) );
      }
      @{$countersArrayRef}[$counterId]->compute('VALUE');
      push( @{$self->{'_OBJECT_MSG'}}, @{$countersArrayRef}[$counterId]->getMsg() );
      push( @{$self->{'_OBJECT_STATE'}}, @{$countersArrayRef}[$counterId]->getState() );
      @{$countersArrayRef}[$counterId]->compute('PERFDATA');
      push( @{$self->{'_OBJECT_MSG'}}, @{$countersArrayRef}[$counterId]->getMsg() );
      push( @{$self->{'_OBJECT_STATE'}}, @{$countersArrayRef}[$counterId]->getState() );
    }
  }
  &NagiosPlugins::Debug::debug(9,blessed($self).'::computeData','END computeData');
}

sub checkThresholds() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug(9,blessed($self).'::checkThresholds','BEGIN checkThresholds');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::checkThresholds','checkThresholds('.$self->{'_OBJECT_NAME'}.')');
  my $countersArrayRef = $self->{'_OBJECT_COUNTERS'};
  my $countersArrayCount = scalar(@{$countersArrayRef});
  &NagiosPlugins::Debug::debug(6,blessed($self).'::checkThresholds','Found '.$countersArrayCount.' counter(s) with thresholds to parse ...');
  for ( my $counterId=0 ; $counterId < scalar(@{$countersArrayRef}) ; $counterId++ ) {
    if ( @{$countersArrayRef}[$counterId]->isHidden() ) {
      &NagiosPlugins::Debug::debug(6,blessed($self).'::checkThresholds','Hidden counter '.@{$countersArrayRef}[$counterId]->getName().'. Nothing to check.');
    } else {
      @{$countersArrayRef}[$counterId]->checkThreshold();
      push( @{$self->{'_OBJECT_MSG'}}, @{$countersArrayRef}[$counterId]->getMsg() );
      push( @{$self->{'_OBJECT_STATE'}}, @{$countersArrayRef}[$counterId]->getState() );
    }
  }
  &NagiosPlugins::Debug::debug(9,blessed($self).'::checkThresholds','END checkThresholds');
}

sub new() {
  my ( $class, $argsHRef ) = @_;
  $class = ref($class) || $class;
  my $self = {};
  bless $self, $class;
  &NagiosPlugins::Debug::debug(9,blessed($self).'::new','BEGIN new');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::new','new('.$class.','.$argsHRef.')');
  $self->_validate($argsHRef);
  $self->_set($argsHRef,'_OBJECT_NAME','name',1);
  $self->_initialize();
  $self->_set($argsHRef,'_OBJECT_COUNTERS','counters',1);
  $self->_set($argsHRef,'_OBJECT_EXPAND_THRESHOLD','expandThreshold',0);
  $self->_set($argsHRef,'_OBJECT_WARNING_THRESHOLDS','warningThresholds',1);
  $self->_set($argsHRef,'_OBJECT_CRITICAL_THRESHOLDS','criticalThresholds',1);
  $self->_set($argsHRef,'_OBJECT_PREVIOUS_DATA_FOLDER','dataFolder',0);
  $self->_set($argsHRef,'_OBJECT_PREVIOUS_DATA_FILE','dataFile',0);
  &NagiosPlugins::Debug::debug(8,blessed($self).'::new','new('.$class.','.$argsHRef.')='.$self);
  &NagiosPlugins::Debug::debug(9,blessed($self).'::new','END new');
  return $self;
}

sub dump() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug(9,blessed($self).'::dump','BEGIN dump');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::dump','dump('.$self->{'_OBJECT_NAME'}.') = { ');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::dump','    _OBJECT_STATE                   => '.join(', ',@{$self->{'_OBJECT_STATE'}}).',');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::dump','    _OBJECT_MSG                     => '.join(', ',@{$self->{'_OBJECT_MSG'}}).',');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::dump','    _OBJECT_PERFDATA_MSG            => '.join(', ',@{$self->{'_OBJECT_PERFDATA_MSG'}}).',');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::dump','    _OBJECT_PREVIOUS_DATA_FOLDER    => '.$self->{'_OBJECT_PREVIOUS_DATA_FOLDER'}.',');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::dump','    _OBJECT_PREVIOUS_DATA_FILE      => '.$self->{'_OBJECT_PREVIOUS_DATA_FILE'}.',');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::dump','    _OBJECT_DATA_TIMESTAMP          => '.$self->{'_OBJECT_DATA_TIMESTAMP'}.',');
  &NagiosPlugins::Debug::debug(8,blessed($self).'::dump','    _OBJECT_DATA_PREVIOUS_TIMESTAMP => '.$self->{'_OBJECT_DATA_PREVIOUS_TIMESTAMP'}.',');
  my $countersArrayRef = $self->{'_OBJECT_COUNTERS'};
  my $countersArrayCount = scalar(@{$countersArrayRef});
  for ( my $counterId=0 ; $counterId < scalar(@{$countersArrayRef}) ; $counterId++ ) {
    @{$countersArrayRef}[$counterId]->dump();
  }
  &NagiosPlugins::Debug::debug(9,blessed($self).'::dump','END dump');
}
1;
__END__


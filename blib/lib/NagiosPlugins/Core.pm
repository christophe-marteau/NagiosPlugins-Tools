package NagiosPlugins::Core;

use warnings;
use strict;
use NagiosPlugins::Debug;
use NagiosPlugins::Objects;
use NagiosPlugins::Counters;
use Carp;
use Scalar::Util 'blessed';
use Getopt::Std;
use Getopt::Long qw(:config no_ignore_case);
use FindBin;
use File::Basename;
use vars qw($PROGNAME);
use lib "$FindBin::Bin";
use lib "/usr/lib/nagios/plugins";
use utils qw (%ERRORS &print_revision);
use Digest::MD5 qw(md5_hex);

our $VERSION = '1.00';

sub _initialize() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_initialize', 'BEGIN _initialize' );
  $self->{'_PLUGIN_NAME'} = basename( $0 ); 
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::_initialize', '_initialize('.$self->{'_PLUGIN_NAME'}.')' );
  $self->{'_PLUGIN_OPTIONS_LAST_ID'} = 0; 
  $self->{'_PLUGIN_OPTIONS_TEMPLATE'} = {
                                         'id'                => {
                                                                 'id'          => 0,
							         'description' => 'Option Identifier (must be unique)',
                                                                 'regex'       => '[0-9]+'
                                                                },
                                          'alias'            => {
                                                                 'id'          => 1,
                                                                 'description' => 'Option Alias (must be unique)',
                                                                 'regex'       => '([^|]+\|)*[^|]*'
                                                                }, 
                                          'argDescription'   => {
                                                                 'id'          => 2,
                                                                 'description' => 'Option argument description (for displaying usage)',
                                                                 'regex'       => '.*'
                                                                },
                                          'shortDescription' => {
                                                                 'id'          => 3,
                                                                 'description' => 'Option short description (for displaying usage)',
                                                                 'regex'       => '.*'
                                                                },
                                          'longDescription'  => {
                                                                 'id'          => 4,
                                                                 'description' => 'Option long description (for displaying usage)',
                                                                 'regex'       => '.*'
                                                                },
                                          'regex'            => {
                                                                 'id'          => 5,
                                                                 'description' => 'Option regular expression check',
                                                                 'regex'       => '.*'
                                                                },
                                          'value'            => {
                                                                 'id'          => 6,
                                                                 'description' => 'Option default value',
                                                                 'regex'       => '.*'
                                                                },
                                          'type'             => {
                                                                 'id'          => 7,
                                                                 'description' => 'Option type ()',
                                                                 'regex'       => '!|\+|=(s|i|o|f)\s*(@|%)?\s*(\{[0-9]*,[0-9]*\})?|:(s|i|o|f)\s*(@|%)?|:[0-9]+\s*(@|%)?|:+\s*(@|%)?'
                                                                },
                                          'enabled'          => {
                                                                 'id'          => 8,
                                                                 'description' => 'Option state (enable or disable)',
                                                                 'regex'       => '0|1'
                                                                },
                                         }; 
  $self->{'_PLUGIN_OPTIONS'} = { 
                                 'version'       =>  {
                                                      'id'               => $self->{'_PLUGIN_OPTIONS_LAST_ID'}++,
                                                      'alias'            => 'V',
                                                      'argDescription'   => '',
                                                      'shortDescription' => 'Display plugin version',
                                                      'longDescription'  => 'Display plugin version',
                                                      'regex'            => '0|1',
                                                      'value'            => 0,
                                                      'type'             => '!',
                                                      'built-in'         => 1,
                                                      'enabled'          => 1
                                                     },
                                 'help'           => {
                                                      'id'               => $self->{'_PLUGIN_OPTIONS_LAST_ID'}++,
                                                      'alias'            => 'h',
                                                      'argDescription'   => '',
                                                      'shortDescription' => 'Display this help',
                                                      'longDescription'  => 'Display this help',
                                                      'regex'            => '0|1',
                                                      'value'            => 0,
                                                      'type'             => '!',
                                                      'built-in'         => 1,
                                                      'enabled'          => 1
                                                     },
                                 'timeout'        => {
                                                      'id'               => $self->{'_PLUGIN_OPTIONS_LAST_ID'}++,
                                                      'alias'            => 't',
                                                      'argDescription'   => 'seconds',
                                                      'shortDescription' => 'Timeout in second before plugins hang',
                                                      'longDescription'  => 'Timeout in second before plugins hang. Default to 10s',
                                                      'regex'            => '[0-9]+',
                                                      'value'            => 10,
                                                      'type'             => '=i',
                                                      'enabled'          => 1
                                                     },
                                 'warning'        => {
                                                      'id'               => $self->{'_PLUGIN_OPTIONS_LAST_ID'}++,
                                                      'alias'            => 'w',
                                                      'argDescription'   => 'threshold list',
                                                      'shortDescription' => 'List of warning tresholds (comma separated)',
                                                      'longDescription'  => 'List of warning tresholds (comma separated)',
                                                      'regex'            => '.*',
                                                      'value'            => '',
                                                      'type'             => '=s',
                                                      'built-in'         => 1,
                                                      'enabled'          => 1
                                                     },
                                 'critical'       => {   
                                                      'id'               => $self->{'_PLUGIN_OPTIONS_LAST_ID'}++,
                                                      'alias'            => 'c',
                                                      'argDescription'   => 'threshold list',
                                                      'shortDescription' => 'List of critical tresholds (comma separated)',
                                                      'longDescription'  => 'List of critical tresholds (comma separated)',
                                                      'regex'            => '.*',
                                                      'value'            => '',
                                                      'type'             => '=s',
                                                      'built-in'         => 1,
                                                      'enabled'          => 1
                                                     },
                                 'hostname'       => {   
                                                      'id'               => $self->{'_PLUGIN_OPTIONS_LAST_ID'}++,
                                                      'alias'            => 'H',
                                                      'argDescription'   => 'hostname',
                                                      'shortDescription' => 'IP or hostname to check',
                                                      'longDescription'  => 'IP or hostname to check',
                                                      'regex'            => '.*',
                                                      'value'            => '',
                                                      'type'             => '=s',
                                                      'enabled'          => 1
                                                     },
                                  'verbose'        => {
                                                      'id'               => $self->{'_PLUGIN_OPTIONS_LAST_ID'}++,
                                                      'alias'            => 'v|d|debug',
                                                      'argDescription'   => 'level',
                                                      'shortDescription' => 'Enable verbose mode',
                                                      'longDescription'  => 'Enable verbose mode from 1 to 9. Default to 0',
                                                      'regex'            => '[0-9]',
                                                      'value'            => 0,
                                                      'type'             => ':+',
                                                      'built-in'         => 1,
                                                      'enabled'          => 1
                                                     },
                                 'community'      => {
                                                      'id'               => $self->{'_PLUGIN_OPTIONS_LAST_ID'}++,
                                                      'alias'            => 'C',
                                                      'argDescription'   => 'community',
                                                      'shortDescription' => 'SNMP community',
                                                      'longDescription'  => 'SNMP community',
                                                      'regex'            => '.*',
                                                      'value'            => '',
                                                      'type'             => '=s',
                                                      'enabled'          => 0
                                                     },
                                 'authentication' => {
                                                      'id'               => $self->{'_PLUGIN_OPTIONS_LAST_ID'}++,
                                                      'alias'            => 'a',
                                                      'argDescription'   => 'auth',
                                                      'shortDescription' => 'Authentication password',
                                                      'longDescription'  => 'Authentication password',
                                                      'regex'            => '.*',
                                                      'value'            => '',
                                                      'type'             => '=s',
                                                      'enabled'          => 0
                                                     },
                                 'logname'        => {
                                                      'id'               => $self->{'_PLUGIN_OPTIONS_LAST_ID'}++,
                                                      'alias'            => 'l',
                                                      'argDescription'   => 'login',
                                                      'shortDescription' => 'Login name',
                                                      'longDescription'  => 'Login name',
                                                      'regex'            => '.*',
                                                      'value'            => '',
                                                      'type'             => '=s',
                                                      'enabled'          => 0
                                                     },
                                 'port'           => {
                                                      'id'               => $self->{'_PLUGIN_OPTIONS_LAST_ID'}++,
                                                      'alias'            => '',
                                                      'argDescription'   => 'port',
                                                      'shortDescription' => 'Port to check',
                                                      'longDescription'  => 'Port to check',
                                                      'regex'            => '|[0-9]+',
                                                      'value'            => '',
                                                      'type'             => '=s',
                                                      'enabled'          => 0
                                                     },
                                 'password'       => {
                                                      'id'               => $self->{'_PLUGIN_OPTIONS_LAST_ID'}++,
                                                      'alias'            => '',
                                                      'argDescription'   => 'password',
                                                      'shortDescription' => 'User password',
                                                      'longDescription'  => 'User password',
                                                      'regex'            => '.*',
                                                      'value'            => '',
                                                      'type'             => '=s',
                                                      'enabled'          => 0
                                                     },
                                 'url'            => {
                                                      'id'               => $self->{'_PLUGIN_OPTIONS_LAST_ID'}++,
                                                      'alias'            => '',
                                                      'argDescription'   => 'url',
                                                      'shortDescription' => 'Url to check',
                                                      'longDescription'  => 'Url to check',
                                                      'regex'            => '.*',
                                                      'value'            => '',
                                                      'type'             => '=s',
                                                      'enabled'          => 0
                                                     },
                                 'username'       => {
                                                      'id'               => $self->{'_PLUGIN_OPTIONS_LAST_ID'}++,
                                                      'alias'            => '',
                                                      'argDescription'   => 'username',
                                                      'shortDescription' => 'User name',
                                                      'longDescription'  => 'User name',
                                                      'regex'            => '.*',
                                                      'value'            => '',
                                                      'type'             => '=s',
                                                      'enabled'          => 0
                                                     },
                                 'perfdata'       => {
                                                      'id'               => $self->{'_PLUGIN_OPTIONS_LAST_ID'}++,
                                                      'alias'            => 'f',
                                                      'argDescription'   => '',
                                                      'shortDescription' => 'Enable perfdata',
                                                      'longDescription'  => 'Enable perfdata output (disable by default)',
                                                      'regex'            => '0|1',
                                                      'value'            => '0',
                                                      'type'             => '!',
                                                      'built-in'         => 1,
                                                      'enabled'          => 1
                                                     },
                                 'perfdatadir'    => {
                                                      'id'               => $self->{'_PLUGIN_OPTIONS_LAST_ID'}++,
                                                      'alias'            => '',
                                                      'argDescription'   => 'perfdata folder',
                                                      'shortDescription' => 'Where to store perfdata file',
                                                      'longDescription'  => 'Folder where to store perfdata file ("/tmp" by default)',
                                                      'regex'            => '(\/[^\/]+)*\/?',
                                                      'value'            => '/tmp',
                                                      'type'             => '=s',
                                                      'built-in'         => 1,
                                                      'enabled'          => 1
                                                     },
                                 'expand-threshold' => {
                                                      'id'               => $self->{'_PLUGIN_OPTIONS_LAST_ID'}++,
                                                      'alias'            => 'e',
                                                      'argDescription'   => 'Expand the threshold value for all counters',
                                                      'shortDescription' => 'Expand the threshold value for all counters',
                                                      'longDescription'  => 'Expand the threshold value for all counters. No by default',
                                                      'regex'            => '0|1',
                                                      'value'            => '0',
                                                      'type'             => '!',
                                                      'built-in'         => 1,
                                                      'enabled'          => 1
                                                     }
                               };
  $self->{'_PLUGIN_USAGE_EXAMPLE'} = [];
  $self->{'_PLUGIN_VERSION'} = '1.0.0';
  $self->{'_PLUGIN_AUTHOR'} = 'Anonymous';
  $self->{'_PLUGIN_OBJECT'} = undef;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_initialize', 'END _initialize' );
}

sub _genDataFileName() {
  my ( $self, $objectName ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_genDataFileName', 'BEGIN _genDataFileName' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::_genDataFileName', '_genDataFileName( '.$self.', '.$objectName.' )' );
  my $generatedDatafileName = '';
  foreach my $optionName ( sort { $self->{'_PLUGIN_OPTIONS'}->{$a}->{'id'} <=> $self->{'_PLUGIN_OPTIONS'}->{$b}->{'id'} } ( keys( %{$self->{'_PLUGIN_OPTIONS'}} ) ) ) {
    if ( $self->{'_PLUGIN_OPTIONS'}->{$optionName}->{'enabled'} == 1 ) {
      if ( $optionName ne 'verbose' ) {
        $generatedDatafileName .= $optionName.$self->{'_PLUGIN_OPTIONS'}->{$optionName}->{'value'}
      }
    }
  }
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::_genDataFileName', '_genDataFileName( '.$self.', '.$objectName.' ) = '.basename( $0 ).'_'.$objectName.'_'.$generatedDatafileName.'.dat' );
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_genDataFileName', 'END _genDataFileName' );
  return( basename( $0 ).'_'.$objectName.'_'.md5_hex( $generatedDatafileName ).'.dat' );
}


sub createObject() {
  my ( $self, $objectName, $counterArrayRef, $needPreviousData ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::createNagiosPluginsObject', 'BEGIN createNagiosPluginsObject' );
  $self->{'_PLUGIN_OBJECT'} = NagiosPlugins::Objects->new(
                                                        {
                                                         'name'               => $objectName,
                                                         'counters'           => $counterArrayRef,
                                                         'warningThresholds'  => $self->{'_PLUGIN_OPTIONS'}->{'warning'}->{'value'},
                                                         'criticalThresholds' => $self->{'_PLUGIN_OPTIONS'}->{'critical'}->{'value'},
                                                         'expandThreshold'    => $self->{'_PLUGIN_OPTIONS'}->{'expand-threshold'}->{'value'},
                                                         'dataFolder'         => $self->{'_PLUGIN_OPTIONS'}->{'perfdatadir'}->{'value'},
                                                         'dataFile'           => $self->_genDataFileName( $objectName )
                                                        }
                                                       );
  if ( $self->{'_PLUGIN_OBJECT'}->getState() eq 'OK' ) {
    $self->{'_PLUGIN_OBJECT'}->parseThresholds();
    if ( $self->{'_PLUGIN_OBJECT'}->getState() eq 'OK' ) {
      $self->{'_PLUGIN_OBJECT'}->computeData( $needPreviousData );
      if ( $self->{'_PLUGIN_OBJECT'}->getState() eq 'OK' ) {
        if ( $self->{'_PLUGIN_OPTIONS'}->{'perfdata'}->{'value'} ) {
          $self->{'_PLUGIN_OBJECT'}->setPerfDataMsg();
        }
        $self->{'_PLUGIN_OBJECT'}->checkThresholds();
      }
    }
  }
  $self->exit( $self->{'_PLUGIN_OBJECT'}->getState(), $self->{'_PLUGIN_OBJECT'}->getMsg(), $self->{'_PLUGIN_OBJECT'}->getPerfDataMsg() );  
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::createNagiosPluginsObject', 'END createNagiosPluginsObject' );
}


sub _checkOptionsSyntax() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_checkOptionsSyntax', 'BEGIN _checkOptionsSyntax' );
  my $aliasList = {};
  my $optionList = {};
  my $idList = {};
  foreach my $optionName ( sort { $self->{'_PLUGIN_OPTIONS'}->{$a}->{'id'} <=> $self->{'_PLUGIN_OPTIONS'}->{$b}->{'id'} } ( keys( %{$self->{'_PLUGIN_OPTIONS'}} ) ) ) {
    &NagiosPlugins::Debug::debug(8,blessed( $self ).'::_checkOptionsSyntax','Parsing option "'.$optionName.'" ...' );
    foreach my $optionAttribute ( sort { $self->{'_PLUGIN_OPTIONS_TEMPLATE'}->{$a}->{'id'} <=> $self->{'_PLUGIN_OPTIONS_TEMPLATE'}->{$b}->{'id'} } ( keys( %{$self->{'_PLUGIN_OPTIONS_TEMPLATE'}} ) ) ) {
      &NagiosPlugins::Debug::debug(8,blessed( $self ).'::_checkOptionsSyntax','Parsing attribute "'.$optionAttribute.'" ...' );
      if ( defined( $self->{'_PLUGIN_OPTIONS'}->{$optionName}->{$optionAttribute} ) ) {
        if ( ( "$optionAttribute" eq 'id') and ( defined ( $aliasList->{$self->{'_PLUGIN_OPTIONS'}->{$optionName}->{'id'}} ) ) ) {
          croak( 'Duplicate id ('.$self->{'_PLUGIN_OPTIONS'}->{$optionName}->{'id'}.') found for option "'.$optionName.'" (used by option "'.$aliasList->{$self->{'_PLUGIN_OPTIONS'}->{$optionName}->{'id'}}.'")' );
        } else {
          $aliasList->{$self->{'_PLUGIN_OPTIONS'}->{$optionName}->{'id'}} = $optionName;
        }
        if ( ( "$optionAttribute" eq 'alias' ) and ( $self->{'_PLUGIN_OPTIONS'}->{$optionName}->{'alias'} ne '' ) ) {
          my @aliasArray = split( '\|', $self->{'_PLUGIN_OPTIONS'}->{$optionName}->{'alias'} );
          for ( my $aliasCpt = 0; $aliasCpt < scalar(@aliasArray); $aliasCpt++ ) {
            &NagiosPlugins::Debug::debug(8,blessed( $self ).'::_checkOptionsSyntax','Parsing alias "'.$aliasArray[$aliasCpt].'" ...' );
            if ( defined ( $aliasList->{$aliasArray[$aliasCpt]} ) ) {
              croak( 'Duplicate alias ('.$aliasArray[$aliasCpt].') found for option "'.$optionName.'" (used by option "'.$aliasList->{"$aliasArray[$aliasCpt]"}.'")' );
            } else {
              $aliasList->{"$aliasArray[$aliasCpt]"} = $optionName;
            }
            if ( defined( $self->{'_PLUGIN_OPTIONS'}->{$aliasArray[$aliasCpt]} ) ) {
              croak( 'Option name match this alias ('.$aliasArray[$aliasCpt].') for option "'.$optionName.'"' );
            }
          }
        } else {
          $aliasList->{$self->{'_PLUGIN_OPTIONS'}->{$optionName}->{'id'}} = $optionName;
        }
        if ( $self->{'_PLUGIN_OPTIONS'}->{$optionName}->{$optionAttribute} =~ /^$self->{'_PLUGIN_OPTIONS_TEMPLATE'}->{$optionAttribute}->{'regex'}$/ ) {
          &NagiosPlugins::Debug::debug(7,blessed( $self ).'::_checkOptionsSyntax','Attribute value "'.$self->{'_PLUGIN_OPTIONS'}->{$optionName}->{$optionAttribute}.'" for attribute "'.$optionAttribute.'" for option "'.$optionName.'" match attribute regex "'.$self->{'_PLUGIN_OPTIONS_TEMPLATE'}->{$optionAttribute}->{'regex'}.'".' );
        } else {
          croak( 'Attribute value "'.$self->{'_PLUGIN_OPTIONS'}->{$optionName}->{$optionAttribute}.'" for attribute "'.$optionAttribute.'" for option "'.$optionName.'" does not match attribute regex "'.$self->{'_PLUGIN_OPTIONS_TEMPLATE'}->{$optionAttribute}->{'regex'}.'".' );
        }
      } else {
        croak( 'You must defined attribute "'.$optionAttribute.'" for option "'.$optionName.'".' );
      }
    } 
  }
  &NagiosPlugins::Debug::debug(9,blessed( $self ).'::_checkOptionsSyntax','END _checkOptionsSyntax');
}

sub addOption() {
  my ( $self, $optionName ,$optionHRef ) = @_;
  &NagiosPlugins::Debug::debug(9,blessed( $self ).'::addOption','BEGIN addOption');
  if ( defined( $self->{'_PLUGIN_OPTIONS'}->{$optionName} ) ) {
    if ( $self->{'_PLUGIN_OPTIONS'}->{$optionName}->{'built-in'} ) {
      croak( 'Can\'t overwrite built-in option "'.$optionName.'".' );
    } else { 
      &NagiosPlugins::Debug::debug(8,blessed( $self ).'::addOption','Option "'.$optionName.'" already exists, overwriting ...');
    }
  } else {
    &NagiosPlugins::Debug::debug(8,blessed( $self ).'::addOption','Option "'.$optionName.'" does not exists, creating ...');
  }
  if ( defined( $optionHRef->{'id'} ) ) {
    &NagiosPlugins::Debug::debug(8,blessed( $self ).'::addOption','User defined id "'.$optionHRef->{'id'}.'" for option "'.$optionName.'" ...' );
  } else {
    $optionHRef->{'id'} = $self->{'_PLUGIN_OPTIONS_LAST_ID'}++;
    &NagiosPlugins::Debug::debug(8,blessed( $self ).'::addOption','generate id "'.$optionHRef->{'id'}.'" for option "'.$optionName.'" ...' );
  } 
  foreach my $optionAttribute ( sort { $self->{'_PLUGIN_OPTIONS_TEMPLATE'}->{$a}->{'id'} <=> $self->{'_PLUGIN_OPTIONS_TEMPLATE'}->{$b}->{'id'} } ( keys( %{$self->{'_PLUGIN_OPTIONS_TEMPLATE'}} ) ) ) {
    &NagiosPlugins::Debug::debug(8,blessed( $self ).'::addOption','Adding attribute "'.$optionAttribute.'" ...' );
    if ( defined( $optionHRef->{$optionAttribute} ) ) {
      &NagiosPlugins::Debug::debug(8,blessed( $self ).'::addOption','Adding attribute "'.$optionAttribute.'" with value "'.$optionHRef->{$optionAttribute}.'".' );
      $self->{'_PLUGIN_OPTIONS'}->{$optionName}->{$optionAttribute} = $optionHRef->{$optionAttribute};
    } else {
      croak( 'You must define attibute "'.$optionAttribute.'" for option "'.$optionName.'".');
    }
  } 
  &NagiosPlugins::Debug::debug(9,blessed( $self ).'::addOption','END addOption');
}

sub disableOption() {
  my ( $self, $optionName ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::disableOption', 'BEGIN disableOption' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::disableOption', 'disableOption('.$optionName.')' );
  if ( defined( $self->{'_PLUGIN_OPTIONS'}->{$optionName} ) ) {
    if ( $self->{'_PLUGIN_OPTIONS'}->{$optionName}->{'built-in'} ) {
      croak( 'Can\'t disable built-in option "'.$optionName.'"'  );
    } else { 
      &NagiosPlugins::Debug::debug( 7, blessed( $self ).'::disableOption','Option "'.$optionName.'" disabled' );
      $self->{'_PLUGIN_OPTIONS'}->{$optionName}->{'enabled'} = 0;
    }
  } else  {
    $self->exit( 'UNKNOWN', 'Option "'.$optionName.'" not found, can\'t disable' );
  }
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::disableOption', 'disableOption('.$optionName.') = 0' );
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::disableOption', 'END disableOption' );
}

sub enableOption() {
  my ( $self, $optionName ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::enableOption', 'BEGIN enableOption' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::enableOption', 'enableOption('.$optionName.')' );
  if ( defined( $self->{'_PLUGIN_OPTIONS'}->{$optionName} ) ) {
    &NagiosPlugins::Debug::debug( 7, blessed( $self ).'::enableOption', 'Option "'.$optionName.'" enabled' );
    $self->{'_PLUGIN_OPTIONS'}->{$optionName}->{'enabled'} = 1;
  } else {
    $self->exit( 'UNKNOWN', 'Option "'.$optionName.'" not found, can\'t enable' );
  }
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::enableOption', 'enableOption('.$optionName.') = 1' );
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::enableOption', 'END enableOption' );
}

sub getOptionValue() {
  my ( $self, $optionName ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getOptionValue', 'BEGIN getOptionValue' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::getOptionValue', 'getOptionValue('.$optionName.')' );
  if ( not( defined( $self->{'_PLUGIN_OPTIONS'}->{$optionName} ) ) ) {
    $self->exit('UNKNOWN', 'Option "'.$optionName.'" not found, can\'t get value');
  }
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::getOptionValue', 'getOptionValue('.$optionName.') = '.$self->{'_PLUGIN_OPTIONS'}->{$optionName}->{'value'} );
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::getOptionValue', 'END getOptionValue' );
  return( $self->{'_PLUGIN_OPTIONS'}->{$optionName}->{'value'} );
}

sub parseOptions() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_parseOptions', 'BEGIN _parseOptions' );
  $self->_checkOptionsSyntax();
  my $hOptions = {};
  foreach my $option ( sort { $self->{'_PLUGIN_OPTIONS'}->{$a}->{'id'} <=> $self->{'_PLUGIN_OPTIONS'}->{$b}->{'id'} } ( keys( %{$self->{'_PLUGIN_OPTIONS'}} ) ) ) {
    if ( $self->{'_PLUGIN_OPTIONS'}->{$option}->{'enabled'} == 1 ) {
      my $optionLabel = $option;
      if ( $self->{'_PLUGIN_OPTIONS'}->{$option}->{'alias'} ne '' ) { 
        $optionLabel .= '|'.$self->{'_PLUGIN_OPTIONS'}->{$option}->{'alias'};
      } 
      $optionLabel .= $self->{'_PLUGIN_OPTIONS'}->{$option}->{'type'};
      $hOptions->{"$optionLabel"} = \$self->{'_PLUGIN_OPTIONS'}->{$option}->{'value'};
      &NagiosPlugins::Debug::debug( 7, blessed( $self ).'::_parseOptions', 'Generating GetOpt option ['.$self->{'_PLUGIN_OPTIONS'}->{$option}->{'id'}.']"'.$option.'" : "'.$optionLabel .'" => "'.$self->{'_PLUGIN_OPTIONS'}->{$option}->{'value'}.'" ...' );
    }
  }
  if ( not( GetOptions (%{$hOptions})) ) {
    $self->_usage();
    $self->exit( 'UNKNOWN', 'Error in command line arguments','' );
  }
  foreach my $option ( sort { $self->{'_PLUGIN_OPTIONS'}->{$a}->{'id'} <=> $self->{'_PLUGIN_OPTIONS'}->{$b}->{'id'} } ( keys( %{$self->{'_PLUGIN_OPTIONS'}} ) ) ) {
    if ( $self->{'_PLUGIN_OPTIONS'}->{$option}->{'enabled'} == 1 ) {
      &NagiosPlugins::Debug::debug( 7, blessed( $self ).'::_parseOptions', 'Parsing option ['.$self->{'_PLUGIN_OPTIONS'}->{$option}->{'id'}.']"'.$option.'" : "'.$self->{'_PLUGIN_OPTIONS'}->{$option}->{'value'}.'" =~ /^'.$self->{'_PLUGIN_OPTIONS'}->{$option}->{'regex'}.'$/' );
      if ( defined( $self->{'_PLUGIN_OPTIONS'}->{$option} ) ) { 
        if ( $self->{'_PLUGIN_OPTIONS'}->{$option}->{'value'} !~ /^$self->{'_PLUGIN_OPTIONS'}->{$option}->{'regex'}$/ ) {
          $self->_usage();
          $self->exit( 'UNKNOWN', 'Bad value "'.$self->{'_PLUGIN_OPTIONS'}->{$option}->{'value'}.'" for option "'.$option.'"', '' );
        }
      }
    }
  }
  if ( $self->{'_PLUGIN_OPTIONS'}->{'help'}->{'value'} ) {
    $self->_usage();
    $self->exit( 'UNKNOWN', 'Displaying plugins usage', '' );
  }
  if ( $self->{'_PLUGIN_OPTIONS'}->{'version'}->{'value'} ) {
    print 'Nagios plugins "'.$self->{'_PLUGIN_NAME'}.'" : '.$self->{'_PLUGIN_DESCRIPTION'}."\n";
    print '  Plugins version : '.$self->{'_PLUGIN_VERSION'}."\n";
    print '  Plugins author  : '.$self->{'_PLUGIN_AUTHOR'}."\n";
    print "\n";
    print 'Use the NagiosPlugins API '."\n";
    print '  NagiosPluginsCore version     : '.NagiosPluginsCore->VERSION()."\n";
    print '  NagiosPluginsObjects version  : '.NagiosPluginsObjects->VERSION()."\n";
    print '  NagiosPluginsCounters version : '.NagiosPluginsCounters->VERSION()."\n";
    print '  Debug version                 : '.Debug->VERSION()."\n";
    $self->exit( 'UNKNOWN', 'Displaying plugins informations', '' );
  }
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_parseOptions', 'END _parseOptions' );
  $NagiosPlugins::Debug::Debug = $self->{'_PLUGIN_OPTIONS'}->{'verbose'}->{'value'};
}

sub _usage() {
  my ( $self ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_usage',' BEGIN _usage' );
  my $printArray = []; 

  push( @{$printArray}, 'NAME'."\n" );
  push( @{$printArray}, '    '.$self->{'_PLUGIN_NAME'}."\n" );
  push( @{$printArray}, "\n" );
 
  push( @{$printArray}, 'DESCRIPTION'."\n" );
  push( @{$printArray}, '    '.$self->{'_PLUGIN_DESCRIPTION'}."\n" );
  push( @{$printArray}, "\n" );
 
  push( @{$printArray}, 'SYNOPSIS'."\n" );
  push( @{$printArray}, "\n" );
 
  push( @{$printArray}, '    Options :'."\n" );
  foreach my $option ( sort { $self->{'_PLUGIN_OPTIONS'}->{$a}->{'id'} <=> $self->{'_PLUGIN_OPTIONS'}->{$b}->{'id'} } ( keys( %{$self->{'_PLUGIN_OPTIONS'}} ) ) ) {
    if ( $self->{'_PLUGIN_OPTIONS'}->{$option}->{'enabled'} == 1 ) {
      my $optionLabel = $option;
      if ( $self->{'_PLUGIN_OPTIONS'}->{$option}->{'argDescription'} ne '' ) {
        $optionLabel .= ' <'.$self->{'_PLUGIN_OPTIONS'}->{$option}->{'argDescription'}.'>' ; 
      }
      push( @{$printArray}, sprintf( "      --%-25s : %s\n", $optionLabel, $self->{'_PLUGIN_OPTIONS'}->{$option}->{'shortDescription'} ) );
    }
  }
  push( @{$printArray}, "\n" );
 
  push( @{$printArray}, 'OPTIONS'."\n" );
  foreach my $option ( sort { $self->{'_PLUGIN_OPTIONS'}->{$a}->{'id'} <=> $self->{'_PLUGIN_OPTIONS'}->{$b}->{'id'} } ( keys( %{$self->{'_PLUGIN_OPTIONS'}} ) ) ) {
    if ( $self->{'_PLUGIN_OPTIONS'}->{$option}->{'enabled'} == 1 ) {
      my $optionLabel = $option;
      if ( $self->{'_PLUGIN_OPTIONS'}->{$option}->{'argDescription'} ne '' ) {
        $optionLabel .= ' <'.$self->{'_PLUGIN_OPTIONS'}->{$option}->{'argDescription'}.'>' ; 
      }
      push( @{$printArray}, sprintf( "    --%s\n", $optionLabel ) );
      push( @{$printArray}, '         '.$self->{'_PLUGIN_OPTIONS'}->{$option}->{'longDescription'}."\n" );
      push( @{$printArray}, "\n" );
    }
  }
  if ( $self->{'_PLUGIN_USAGE_EXAMPLE'} ne '' ) {
    push( @{$printArray}, 'EXAMPLES'."\n" );
    for( my $lineCpt = 0 ; $lineCpt < scalar( @{$self->{'_PLUGIN_USAGE_EXAMPLE'}} ) ; $lineCpt++ ) {
      push ( @{$printArray}, '    '.@{$self->{'_PLUGIN_USAGE_EXAMPLE'}}[$lineCpt]."\n" );
    }
    push( @{$printArray}, "\n" );
  }

  for( my $lineCpt = 0 ; $lineCpt < scalar( @{$printArray} ) ; $lineCpt++ ) {
    print @{$printArray}[$lineCpt];
  }
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_usage', 'END _usage' );
}

sub _set() {
  my ( $self, $hRef, $selfKey, $hKey, $isRequired ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_set', 'BEGIN _set' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::_set', '_set(self,hRef,'.$selfKey.','.$hKey.','.$isRequired.')' );
  if ( defined( $hRef->{$hKey} ) ) {
    &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::_set', '_set(self,hRef,'.$selfKey.','.$hKey.','.$isRequired.')='.$hRef->{$hKey} );
    if ( $hKey eq 'usageExample' ) {
      if ( ref( $hRef->{$hKey} ) eq 'ARRAY' ) {
        $self->{$selfKey} = $hRef->{$hKey};
      } else {
        croak( 'Type of usageExample must be an array reference' );
      }
    } else {
      $self->{$selfKey} = $hRef->{$hKey};
    }
  } else {
    if ( $isRequired ) {
      croak( 'You must defined a "'.$hKey.'" for this plugin.' );
    }
  }
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_set', 'END _set' );
}

sub _validate() {
  my ( $self, $hRef ) = @_;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_validate', 'BEGIN _validate' );
  foreach my $hKey ( keys( %{$hRef} ) ) {
    &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_validate', '_validate('.$hKey.')' );
    if ( $hKey !~ /^(name|description|usageExample|version|author)$/ ) {
      croak(' Undefined plugin propertie "'.$hKey.'"' );
    }
  }
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::_validate', 'END _validate' );
}


sub new() {
  my ( $class, $argsHRef ) = @_;
  $class = ref( $class ) || $class;
  my $self = {};
  bless $self, $class;
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::new', 'BEGIN new' );
  &NagiosPlugins::Debug::debug( 8, blessed( $self ).'::new', 'new('.$class.','.$argsHRef.')' );
  $self->_validate( $argsHRef );
  $self->_initialize();
  $self->_set( $argsHRef, '_PLUGIN_DESCRIPTION', 'description', 1 );
  $self->_set( $argsHRef, '_PLUGIN_NAME', 'name', 0 );
  $self->_set( $argsHRef, '_PLUGIN_VERSION', 'version', 0 );
  $self->_set( $argsHRef, '_PLUGIN_AUTHOR', 'author', 0 );
  $self->_set( $argsHRef, '_PLUGIN_USAGE_EXAMPLE', 'usageExample', 0 );
  &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::new', 'END new' );
  return $self;
}


# This function displays the nagios status,message and performance data
# and exit with the associate nagios status.
# [in] $status : The nagios status (OK, WARNING, CRITICAL or UNKNOWN)
# [in] $message : The nagios message to display
# [in] $perfData : The performance data string to display, or undef if not exist
sub exit() {
    my ( $self, $status, $message, $perfData ) = @_;
    &NagiosPlugins::Debug::debug( 9, blessed( $self ).'exit', 'BEGIN exit' );
    if ( ( defined( $perfData ) ) && ( $perfData ne '') ) {
      &NagiosPlugins::Debug::debug( 7, blessed( $self ).'::exit', 'exit('.$status.','.$message.','.$perfData.')' );
      $perfData=' | '.$perfData;
    } else {
      $perfData='';
      &NagiosPlugins::Debug::debug( 7, blessed( $self ).'::exit', 'exit('.$status.','.$message.','.$perfData.')' );
    }
    print $status.': '.$message.$perfData."\n";
    &NagiosPlugins::Debug::debug( 9, blessed( $self ).'::exit', 'END exit' );
    exit $ERRORS{$status};
}

1;
__END__

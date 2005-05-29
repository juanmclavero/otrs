# --
# Kernel/Modules/AdminSysConfig.pm - to change ConfigParameter
# Copyright (C) 2001-2005 Martin Edenhofer <martin+code@otrs.org>
# --
# $Id: AdminSysConfig.pm,v 1.25 2005-05-29 16:06:15 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

package Kernel::Modules::AdminSysConfig;

# use ../../ as lib location
use FindBin qw($Bin);
use lib "$Bin/../..";
use lib "$Bin/../../Kernel/cpan-lib";

use strict;
use Kernel::System::Config;

use vars qw($VERSION);
$VERSION = '$Revision: 1.25 $';
$VERSION =~ s/^\$.*:\W(.*)\W.+?$/$1/;

# --
sub new {
    my $Type = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless ($Self, $Type);

    # get common opjects
    foreach (keys %Param) {
        $Self->{$_} = $Param{$_};
    }

    # check all needed objects
    foreach (qw(ParamObject DBObject LayoutObject ConfigObject LogObject)) {
        die "Got no $_" if (!$Self->{$_});
    }

    $Self->{SysConfigObject} = Kernel::System::Config->new(%Param);

    return $Self;
}
# --
sub Run {
    my $Self = shift;
    my %Param = @_;
    my $Output = '';
    my %Data;
    my $Group = '';
    my %InvalidValue;
    my $Anker = '';
    
    $Data{Search} = $Self->{ParamObject}->GetParam(Param => 'Search');
    # update config
    if ($Self->{Subaction} eq 'Update') {
#        $Self->{SysConfigObject}->CreateConfig();
        my $SubGroup = $Self->{ParamObject}->GetParam(Param => 'SysConfigSubGroup');
        my $Group = $Self->{ParamObject}->GetParam(Param => 'SysConfigGroup');
        my @List = $Self->{SysConfigObject}->ConfigSubGroupConfigItemList(Group => $Group, SubGroup => $SubGroup);
        # list all Items
        foreach (@List) {
            # Get all Attributes from Item
            my %ItemHash = $Self->{SysConfigObject}->ConfigItemGet(Name => $_);
            # Get ElementAktiv (checkbox)
            my $Aktiv = 0;
            if (($ItemHash{Required} && $ItemHash{Required} == 1) || $Self->{ParamObject}->GetParam(Param => $_.'ItemAktiv') == 1) {
                $Aktiv = 1;
            }
            # ConfigElement String
            if (defined ($ItemHash{Setting}[1]{String})) {
                # Get Value (Content)
                my $Content = $Self->{ParamObject}->GetParam(Param => $_);
                # Regex check
                if (defined ($ItemHash{Setting}[1]{String}[1]{Regex}) && $ItemHash{Setting}[1]{String}[1]{Regex} ne "" && !($Content =~ /$ItemHash{Setting}[1]{String}[1]{Regex}/)) {
                    $InvalidValue{$_} = 1;
                    $Anker = $ItemHash{Name};
                }
                # write ConfigItem
                if (!$Self->{SysConfigObject}->ConfigItemUpdate(Key => $_, Value => $Content, Valid => $Aktiv)) {
                    $Self->{LayoutObject}->FatalError(Message => "Can't write ConfigItem!");
                }
            }
            # ConfigElement TextArea
            if (defined ($ItemHash{Setting}[1]{TextArea})) {
                # Get Value (Content)
                my $Content = $Self->{ParamObject}->GetParam(Param => $_);
                # write ConfigItem
                if (!$Self->{SysConfigObject}->ConfigItemUpdate(Key => $_, Value => $Content, Valid => $Aktiv)) {
                    $Self->{LayoutObject}->FatalError(Message => "Can't write ConfigItem!");
                }
            }
            # ConfigElement PulldownMenue
            elsif (defined ($ItemHash{Setting}[1]{Option})) {
                my $Content = $Self->{ParamObject}->GetParam(Param => $_);
                # write ConfigItem
                if (!$Self->{SysConfigObject}->ConfigItemUpdate(Key => $_, Value => $Content, Valid => $Aktiv)) {
                    $Self->{LayoutObject}->FatalError(Message => "Can't write ConfigItem!");
                }
            }
            # ConfigElement Hash
            elsif (defined ($ItemHash{Setting}[1]{Hash})) {
                my @Keys   = $Self->{ParamObject}->GetArray(Param => $_.'Key[]');
                my @Values = $Self->{ParamObject}->GetArray(Param => $_.'Content[]');
                my @DeleteNumber = $Self->{ParamObject}->GetArray(Param => $_.'DeleteNumber[]');
                my %Content;
                foreach my $Index (0...$#Keys) {
                    # SubHash
                    if ($Values[$Index] eq '##SubHash##') {
                        my @SubHashKeys   = $Self->{ParamObject}->GetArray(Param => $_.'##SubHash##'.$Keys[$Index].'Key[]');
                        my @SubHashValues = $Self->{ParamObject}->GetArray(Param => $_.'##SubHash##'.$Keys[$Index].'Content[]');
                        my %SubHash;
                        foreach my $Index2 (0...$#SubHashKeys) {
                            # Delete SubHash Element?                  
                            if (!$Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'##SubHash##'.$Keys[$Index].'#DeleteSubHashElement'.($Index2+1))) {
                                $SubHash{$SubHashKeys[$Index2]} = $SubHashValues[$Index2];
                            }
                            else {
                                $Anker = $ItemHash{Name};
                            }
                        }
                        # New SubHashElement
                        if ($Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#'.$Keys[$Index].'#NewSubElement')) {
                            $Anker = $ItemHash{Name};
                        }                              
                        # New SubHashElement
                        if ($Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#'.$ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Key}.'#NewSubElement')) {
                            $SubHash{''} = '';
                        }
                        $Content{$Keys[$Index]} = \%SubHash;
                    }
                    # SubArray
                    elsif ($Values[$Index] eq '##SubArray##') {
                        my @SubArray = $Self->{ParamObject}->GetArray(Param => $_.'##SubArray##'.$Keys[$Index].'Content[]');
                        # New SubArrayElement
                        if ($Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#'.$Keys[$Index].'#NewSubElement')) {
                            push (@SubArray, '');
                            $Anker = $ItemHash{Name};
                        }      
                        #Delete SubArray Element?
                        foreach my $Index2 (0...$#SubArray) {
                            if ($Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'##SubArray##'.$Keys[$Index].'#DeleteSubArrayElement'.($Index2+1))) {
                                splice(@SubArray,$Index2,1);
                                $Anker = $ItemHash{Name};
                            }
                        }
                        $Content{$Keys[$Index]} = \@SubArray;
                    }
                    # Delete Hash Element?
                    elsif (!$Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#DeleteHashElement'.$DeleteNumber[$Index])) {
                        $Content{$Keys[$Index]} = $Values[$Index];
                    }
                    else {
                        $Anker = $ItemHash{Name};
                    }
                }
                # New HashElement
                if ($Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#NewHashElement')) {
                    $Anker = $ItemHash{Name};
                }                                          
                if ($Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#NewHashElement')) {
                    $Content{''} = '';
                }
                # write ConfigItem
                if (!$Self->{SysConfigObject}->ConfigItemUpdate(Key => $_, Value => \%Content, Valid => $Aktiv)) {
                    $Self->{LayoutObject}->FatalError(Message => "Can't write ConfigItem!");
                }
            }
            # ConfigElement Array
            elsif (defined ($ItemHash{Setting}[1]{Array})) {
                my @Content = $Self->{ParamObject}->GetArray(Param => $_.'Content[]');
                # New ArrayElement
                if ($Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#NewArrayElement')) {
                    push (@Content, '');
                    $Anker = $ItemHash{Name};
                }
                #Delete Array Element
                foreach my $Index (0...$#Content) {
                    if ($Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#DeleteArrayElement'.($Index+1))) {
                        splice(@Content,$Index,1);
                        $Anker = $ItemHash{Name};
                    }
                }
                # write ConfigItem
                if (!$Self->{SysConfigObject}->ConfigItemUpdate(Key => $_, Value => \@Content, Valid => $Aktiv)) {
                    $Self->{LayoutObject}->FatalError(Message => "Can't write ConfigItem!");
                }
            }
            # ConfigElement FrontendModuleReg
            elsif (defined ($ItemHash{Setting}[1]{FrontendModuleReg})) {
                my $ElementKey = $_;
                my %Content;
                # get Params
                foreach (qw (Description Title NavBarName)) {
                    if (my $Value = $Self->{ParamObject}->GetParam(Param => $ElementKey.'#'.$_)) {
                        $Content{$_} = $Value;
                    }
                }
                foreach my $Typ (qw (Group GroupRo)) {
                    my @Group = $Self->{ParamObject}->GetArray(Param => $ElementKey.'#'.$Typ.'[]');
                    # New Group(Ro)Element
                    if ($Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#New'.$Typ.'Element')) {
                        push (@Group, '');
                        $Anker = $ItemHash{Name};
                    }                   
                    #Delete Group Element
                    foreach my $Index (0...$#Group) {
                        if ($Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#Delete'.$Typ.'Element'.($Index+1))) {
                            splice(@Group,$Index,1);
                            $Anker = $ItemHash{Name};
                        }
                    }
                    if ($#Group > -1) {
                        $Content{$Typ} = \@Group;
                    }
                }
                # NavBar get Params
                my %NavBarParams;
                foreach (qw (Description Name Image Link Typ Prio Block NavBar AccessKey)) {
                    my @Param = $Self->{ParamObject}->GetArray(Param => $ElementKey.'#NavBar#'.$_.'[]');
                    $NavBarParams{$_} = \@Param;
                }
                # Create Hash
                foreach my $Index (0...$#{$NavBarParams{Description}}) {
                    foreach my $Typ (qw (Group GroupRo)) {
                        my @Group = $Self->{ParamObject}->GetArray(Param => $ElementKey.'#NavBar'.($Index+1).'#'.$Typ.'[]');
                        # New Group(Ro)Element
                        if ($Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#NavBar'.($Index+1).'#New'.$Typ.'Element')) {
                            push (@Group, '');
                            $Anker = $ItemHash{Name};
                        }                        
                        #Delete Group Element
                        foreach my $Index2 (0...$#Group) {
                            if ($Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#NavBar'.($Index+1).'#Delete'.$Typ.'Element'.($Index2+1))) {
                                splice(@Group,$Index2,1);
                                $Anker = $ItemHash{Name};
                            }
                        }
                        if ($#Group > -1) {
                            $Content{NavBar}[$Index]{$Typ} = \@Group;
                        }
                    }
                    foreach (qw (Description Name Image Link Typ Prio Block NavBar AccessKey)) {
                        $Content{NavBar}[$Index]{$_} = $NavBarParams{$_}[$Index];
                    }
                }
                # NavBarModule
                if ($Self->{ParamObject}->GetArray(Param => $ElementKey.'#NavBarModule#Module[]')) {
                    # get Params
                    my %NavBarModuleParams;
                    foreach (qw (Module Name Block Prio)) {
                        my @Param = $Self->{ParamObject}->GetArray(Param => $ElementKey.'#NavBarModule#'.$_.'[]');
                        $NavBarModuleParams{$_} = \@Param;
                    }
                    # Create Hash
                    foreach (qw (Group GroupRo Module Name Block Prio)) {
                        $Content{NavBarModule}{$_} = $NavBarModuleParams{$_}[0];
                    }
                }
                # write ConfigItem
                if (!$Self->{SysConfigObject}->ConfigItemUpdate(Key => $_, Value => \%Content, Valid => $Aktiv)) {
                    $Self->{LayoutObject}->FatalError(Message => "Can't write ConfigItem!");
                }
            }
            # ConfigElement TimeVacationDaysOneTime
            elsif (defined ($ItemHash{Setting}[1]{TimeVacationDaysOneTime})) {
                my @Year   = $Self->{ParamObject}->GetArray(Param => $_.'year[]');
                my @Month  = $Self->{ParamObject}->GetArray(Param => $_.'month[]');
                my @Day    = $Self->{ParamObject}->GetArray(Param => $_.'day[]');
                my @Values = $Self->{ParamObject}->GetArray(Param => $_.'Content[]');
                my %Content;
                foreach my $Index (0...$#Year) {
                    # Delete TimeVacationDaysOneTime Element?
                    if (!$Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#DeleteTimeVacationDaysOneTimeElement'.($Index+1))) {
                        $Content{$Year[$Index]}{$Month[$Index]}{$Day[$Index]} = $Values[$Index];
                    }
                    else {
                        $Anker = $ItemHash{Name};
                    }
                }
                # New TimeVacationDaysOneTimeElement
                if ($Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#NewTimeVacationDaysOneTimeElement')) {
                    $Anker = $ItemHash{Name};
                }                      
                # write ConfigItem
                if (!$Self->{SysConfigObject}->ConfigItemUpdate(Key => $_, Value => \%Content, Valid => $Aktiv)) {
                    $Self->{LayoutObject}->FatalError(Message => "Can't write ConfigItem!");
                }            
            }
            # ConfigElement TimeVacationDays
            elsif (defined ($ItemHash{Setting}[1]{TimeVacationDays})) {
                my @Month  = $Self->{ParamObject}->GetArray(Param => $_.'month[]');
                my @Day    = $Self->{ParamObject}->GetArray(Param => $_.'day[]');
                my @Values = $Self->{ParamObject}->GetArray(Param => $_.'Content[]');
                my %Content;
                foreach my $Index (0...$#Month) {
                    # Delete TimeVacationDays Element?
                    if (!$Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#DeleteTimeVacationDaysElement'.($Index+1))) {
                        $Content{$Month[$Index]}{$Day[$Index]} = $Values[$Index];
                    }
                    else {
                        $Anker = $ItemHash{Name};
                    }
                }
                # New TimeVacationDaysElement
                if ($Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#NewTimeVacationDaysElement')) {
                    $Anker = $ItemHash{Name};
                }                  
                # write ConfigItem
                if (!$Self->{SysConfigObject}->ConfigItemUpdate(Key => $_, Value => \%Content, Valid => $Aktiv)) {
                    $Self->{LayoutObject}->FatalError(Message => "Can't write ConfigItem!");
                }            
            }
            # ConfigElement TimeWorkingHours
            elsif (defined ($ItemHash{Setting}[1]{TimeWorkingHours})) {
                my %Content;
                foreach my $Index (1...$#{$ItemHash{Setting}[1]{TimeWorkingHours}[1]{Day}}) {
                    my $Weekday = $ItemHash{Setting}[1]{TimeWorkingHours}[1]{Day}[$Index]{Name};
                    my @Hours   = $Self->{ParamObject}->GetArray(Param => $_.$Weekday.'[]');
                    $Content{$Weekday} = \@Hours;
                }
                # write ConfigItem
                if (!$Self->{SysConfigObject}->ConfigItemUpdate(Key => $_, Value => \%Content, Valid => $Aktiv)) {
                    $Self->{LayoutObject}->FatalError(Message => "Can't write ConfigItem!");
                }
            }
        }
        $Self->{SysConfigObject} = Kernel::System::Config->new(%{$Self});
        $Self->{SysConfigObject}->CreateConfig();
        # redirect
        return $Self->{LayoutObject}->Redirect(OP => "Action=$Self->{Action}&Subaction=Edit&SysConfigSubGroup=$SubGroup&SysConfigGroup=$Group&Anker=$Anker#Anker");
    }
    # edit config
    if ($Self->{Subaction} eq 'Edit') {
        my $SubGroup = $Self->{ParamObject}->GetParam(Param => 'SysConfigSubGroup');
        my $Group = $Self->{ParamObject}->GetParam(Param => 'SysConfigGroup');
        my $Anker = $Self->{ParamObject}->GetParam(Param => 'Anker') || '';
        my @List = $Self->{SysConfigObject}->ConfigSubGroupConfigItemList(Group => $Group, SubGroup => $SubGroup);
        #Language
        my $UserLang = $Self->{UserLanguage} || $Self->{ConfigObject}->Get('DefaultLanguage');
        # list all Items
        foreach (@List) {
            # Get all Attributes from Item
            my %ItemHash = $Self->{SysConfigObject}->ConfigItemGet(Name => $_);
            # Required
            my $Required = '';
            if ($ItemHash{Required}) {
                $Required = 'disabled';
            }
            # Diff 
            my $Diff = '';
            my $DiffStyle = 'contentvalue';
            if ($ItemHash{Diff}) {
                $DiffStyle = 'contenthead';
            }
            # Valid
            my $Valid = '';
            my $Validstyle = 'passiv';
            if ($ItemHash{Valid}) {
                $Valid = 'checked';
                $Validstyle = '';
            }
            #Description
            my %HashLang;
            foreach my $Index (1...$#{$ItemHash{Description}}) {
                $HashLang{$ItemHash{Description}[$Index]{Lang}} = $ItemHash{Description}[$Index]{Content};
            }
            my $Description;
            # Description in User Language
            if (defined $HashLang{$UserLang}) {
                $Description = $HashLang{$UserLang};
            }
            # Description in Default Language
            else {
                $Description = $HashLang{'en'};
            }
            my $AnkerAktiv = '';
            if ($Anker eq $_) {
                $AnkerAktiv = '<a name="Anker">';
            }
            $Self->{LayoutObject}->Block(
                Name => 'ConfigElementBlock',
                Data => {
                    ItemKey     => $_,
                    Description => $Description,
                    Valid       => $Valid,
                    Validstyle  => $Validstyle,
                    Required    => $Required,
                    Diff        => $Diff,
                    DiffStyle   => $DiffStyle,
                    Anker       => $AnkerAktiv,
                },
            );

            # ListConfigItem
            $Self->ListConfigItem(Hash => \%ItemHash, InvalidValue => \%InvalidValue);
        }
        $Data{SubGroup} = $SubGroup;
        $Data{Group} = $Group;
        $Output .= $Self->{LayoutObject}->Header(Area => 'Admin', Title => 'SysConfig');
        $Output .= $Self->{LayoutObject}->NavigationBar();
        $Output .= $Self->{LayoutObject}->Output(TemplateFile => 'AdminSysConfigEdit', Data => \%Data);
        $Output .= $Self->{LayoutObject}->Footer();
        return $Output;
    }
    # search config
    elsif ($Self->{Subaction} eq 'Search') {
        my %Groups = $Self->{SysConfigObject}->ConfigGroupList();
        foreach my $Group (sort keys(%Groups)) {
            my %SubGroups = $Self->{SysConfigObject}->ConfigSubGroupList(Name => $Group);
            foreach my $SubGroup (sort keys %SubGroups) {
                my $Found = 0;
                my @Items = $Self->{SysConfigObject}->ConfigSubGroupConfigItemList(Group => $Group, SubGroup => $SubGroup);
                foreach my $Item (@Items) {
                    if ($Item =~ /$Data{Search}/i) {
                        $Found = 1;
                    }
                    else {
                        my %ItemHash = $Self->{SysConfigObject}->ConfigItemGet(Name => $Item);
                        foreach my $Index (1...$#{$ItemHash{Description}}) {
                            my $Description = $ItemHash{Description}[$Index]{Content};
                            if ($Description =~ /$Data{Search}/i) {
                                $Found = 1;
                            }
                        }
                    }
                }
                if ($Found == 1) {
                    $Self->{LayoutObject}->Block(
                        Name  => 'Row',
                        Data  => {
                            SubGroup => $SubGroup,
                            SubGroupCount => $SubGroups{$SubGroup},
                            Group    => $Group,
                        },
                    );
                }
            }
        }
    }
    # list subgroups
    elsif ($Self->{Subaction} eq 'SelectGroup') {
        $Group = $Self->{ParamObject}->GetParam(Param => 'SysConfigGroup');
        my %List = $Self->{SysConfigObject}->ConfigSubGroupList(Name => $Group);
        foreach (sort keys %List) {
            $Self->{LayoutObject}->Block(
                Name  => 'Row',
                Data  => {
                    SubGroup => $_,
                    SubGroupCount => $List{$_},
                    Group    => $Group,
                },
            );
        }
    }
    # SessionScreen
    if (!$Self->{SessionObject}->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'LastScreenOverview',
        Value     => $Self->{RequestedURL},
    )) {
        return $Self->{LayoutObject}->ErrorScreen();
    }

    # list Groups
    my %List = $Self->{SysConfigObject}->ConfigGroupList();
    # create select Box
    $Data{Liste} = $Self->{LayoutObject}->OptionStrgHashRef(
        Data     => \%List,
        Selected => $Group,
        Name     => 'SysConfigGroup',
    );

    $Output .= $Self->{LayoutObject}->Header(Area => 'Admin', Title => 'SysConfig');
    $Output .= $Self->{LayoutObject}->NavigationBar();
    $Output .= $Self->{LayoutObject}->Output(TemplateFile => 'AdminSysConfig', Data => \%Data);
    $Output .= $Self->{LayoutObject}->Footer();
    return $Output;
}


sub ListConfigItem {
    my $Self = shift;
    my %Param = @_;
    my %ItemHash    = %{$Param{Hash}};
    my %InvalidValue = %{$Param{InvalidValue}};
    my $Valid = '';
    my $Default = '';
    # ConfigElement String
    if (defined ($ItemHash{Setting}[1]{String})) {
        if (defined ($InvalidValue{$ItemHash{Name}})) {
            $Valid = 'Invalid Value!';
        }
        if ($ItemHash{Setting}[1]{String}[1]{Default} ne '' && $ItemHash{Setting}[1]{String}[1]{Default} ne ' ') {
            $Default = $ItemHash{Setting}[1]{String}[1]{Default};
        }
        $Self->{LayoutObject}->Block(
            Name => 'ConfigElementString',
            Data => {
                ElementKey => $ItemHash{Name},
                Content    => $ItemHash{Setting}[1]{String}[1]{Content},
                Valid      => $Valid,
                Default    => $Default,
            },
        );
    }
    # ConfigElement TextArea
    elsif (defined ($ItemHash{Setting}[1]{TextArea})) {
        $Self->{LayoutObject}->Block(
            Name => 'ConfigElementTextArea',
            Data => {
                ElementKey => $ItemHash{Name},
                Content    => $ItemHash{Setting}[1]{TextArea}[1]{Content},
                Valid      => $Valid,
            },
        );
    }
    # ConfigElement PulldownMenue
    elsif (defined ($ItemHash{Setting}[1]{Option})) {
        my %Hash;
        my $Default = '';
        foreach my $Index (1...$#{$ItemHash{Setting}[1]{Option}[1]{Item}}) {
            $Hash{$ItemHash{Setting}[1]{Option}[1]{Item}[$Index]{Key}} = $ItemHash{Setting}[1]{Option}[1]{Item}[$Index]{Content};
            if ($ItemHash{Setting}[1]{Option}[1]{Item}[$Index]{Key} eq $ItemHash{Setting}[1]{Option}[1]{Default}) {
                $Default = $ItemHash{Setting}[1]{Option}[1]{Item}[$Index]{Content};
            }
        }
        my $PulldownMenue = $Self->{LayoutObject}->OptionStrgHashRef(
            Data       => \%Hash,
            SelectedID => $ItemHash{Setting}[1]{Option}[1]{SelectedID},
            Name       => $ItemHash{Name},
        );
        $Self->{LayoutObject}->Block(
            Name => 'ConfigElementSelect',
            Data => {
                Item        => $ItemHash{Name},
                Liste       => $PulldownMenue,
                Default     => $Default,
            },
        );
    }
    # ConfigElement Hash
    elsif (defined ($ItemHash{Setting}[1]{Hash})) {
        $Self->{LayoutObject}->Block(
            Name => 'ConfigElementHash',
            Data => {
                ElementKey => $ItemHash{Name},
            },
        );
#        $Self->{LogObject}->Dumper(ddd => $ItemHash{Setting}[1]{Hash});
        # Hashelements
        foreach my $Index (1...$#{$ItemHash{Setting}[1]{Hash}[1]{Item}}) {
            #SubHash
            if (defined($ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Hash})) {
                $Self->{LayoutObject}->Block(
                    Name => 'ConfigElementHashContent2',
                    Data => {
                        ElementKey => $ItemHash{Name},
                        Key        => $ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Key},
                        Content    => '##SubHash##',
                        Index      => $Index,
                    },
                );
                # SubHashElements
                foreach my $Index2 (1...$#{$ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Hash}[1]{Item}}) {
                    $Self->{LayoutObject}->Block(
                        Name => 'ConfigElementSubHashContent',
                        Data => {
                            ElementKey => $ItemHash{Name}.'##SubHash##'.$ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Key},
                            Key        => $ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Hash}[1]{Item}[$Index2]{Key},
                            Content    => $ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Hash}[1]{Item}[$Index2]{Content},
                            Index      => $Index,
                            Index2     => $Index2,
                        },
                    );
                }
            }
            #SubArray
            elsif (defined($ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Array})) {
                $Self->{LayoutObject}->Block(
                    Name => 'ConfigElementHashContent2',
                    Data => {
                        ElementKey => $ItemHash{Name},
                        Key        => $ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Key},
                        Content    => '##SubArray##',
                        Index      => $Index,
                    },
                );
                # SubArrayElements
                foreach my $Index2 (1...$#{$ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Array}[1]{Item}}) {
                    $Self->{LayoutObject}->Block(
                        Name => 'ConfigElementSubArrayContent',
                        Data => {
                            ElementKey => $ItemHash{Name}.'##SubArray##'.$ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Key},
                            Content    => $ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Array}[1]{Item}[$Index2]{Content},
                            Index      => $Index,
                            Index2     => $Index2,
                        },
                    );
                }
            }
            #SubOption
            elsif (defined($ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Option})) {
                # Pulldownmenue
                my %Hash;
                foreach my $Index2 (1...$#{$ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Option}[1]{Item}}) {
                    $Hash{$ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Option}[1]{Item}[$Index2]{Key}} = $ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Option}[1]{Item}[$Index2]{Content};
                }
                my $PulldownMenue = $Self->{LayoutObject}->OptionStrgHashRef(
                    Data       => \%Hash,
                    SelectedID => $ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Option}[1]{SelectedID},
                    Name       => $ItemHash{Name}.'Content[]',
                );
                $Self->{LayoutObject}->Block(
                    Name => 'ConfigElementHashContent3',
                    Data => {
                        ElementKey => $ItemHash{Name},
                        Key        => $ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Key},
                        Liste      => $PulldownMenue,
                        Index      => $Index,
                    },
                );
            }
            # StandardElement
            else {
                $Self->{LayoutObject}->Block(
                    Name => 'ConfigElementHashContent',
                    Data => {
                        ElementKey => $ItemHash{Name},
                        Key        => $ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Key},
                        Content    => $ItemHash{Setting}[1]{Hash}[1]{Item}[$Index]{Content},
                        Index      => $Index,
                    },
                );
            }
        }
    }
    # ConfigElement Array
    elsif (defined ($ItemHash{Setting}[1]{Array})) {
        $Self->{LayoutObject}->Block(
            Name => 'ConfigElementArray',
            Data => {
                ElementKey => $ItemHash{Name},
            },
        );
        # ArrayElements
        foreach my $Index (1...$#{$ItemHash{Setting}[1]{Array}[1]{Item}}) {
            $Self->{LayoutObject}->Block(
                Name => 'ConfigElementArrayContent',
                Data => {
                    ElementKey => $ItemHash{Name},
                    Content    => $ItemHash{Setting}[1]{Array}[1]{Item}[$Index]{Content},
                    Index      => $Index,
                },
            );
        }               
    }
    # ConfigElement FrontendModuleReg
    elsif (defined ($ItemHash{Setting}[1]{FrontendModuleReg})) {
#    $Self->{LogObject}->Dumper(fdsa => $ItemHash{Setting}[1]{FrontendModuleReg});
        my %Data = {};
        foreach my $Key qw (Title Description NavBarName) {
            $Data{'Key'.$Key} = $Key;
            $Data{'Content'.$Key} = '';
            if (defined ($ItemHash{Setting}[1]{FrontendModuleReg}[1]{$Key})) {
                $Data{'Content'.$Key} = $ItemHash{Setting}[1]{FrontendModuleReg}[1]{$Key}[1]{Content};
            }
        }
        $Data{ElementKey} = $ItemHash{Name};
        $Self->{LayoutObject}->Block(
            Name => 'ConfigElementFrontendModuleReg',
            Data => \%Data,
        );
        # Array Element Group
        foreach my $ArrayElement qw(Group GroupRo) {
            foreach my $Index (1...$#{$ItemHash{Setting}[1]{FrontendModuleReg}[1]{$ArrayElement}}) {                    
                $Self->{LayoutObject}->Block(
                    Name => 'ConfigElementFrontendModuleRegContent'.$ArrayElement,
                    Data => {
                        Index      => $Index,
                        ElementKey => $ItemHash{Name},
                        Content    => $ItemHash{Setting}[1]{FrontendModuleReg}[1]{$ArrayElement}[$Index]{Content},
                    },
                );
            }
        }
        # NavBar
        foreach my $Index (1...$#{$ItemHash{Setting}[1]{FrontendModuleReg}[1]{NavBar}}) {
            my %Data = {};
            foreach my $Key qw (Description Name Image Link Typ Prio Block NavBar AccessKey) {
                $Data{'Key'.$Key} = $Key;
                $Data{'Content'.$Key} = '';
                if (defined ($ItemHash{Setting}[1]{FrontendModuleReg}[1]{NavBar}[1]{$Key}[1]{Content})) {
                    $Data{'Content'.$Key} = $ItemHash{Setting}[1]{FrontendModuleReg}[1]{NavBar}[$Index]{$Key}[1]{Content};
                }
            }
            $Data{ElementKey} = $ItemHash{Name}.'#NavBar';
            $Data{Index} = $Index;
            $Self->{LayoutObject}->Block(
                Name => 'ConfigElementFrontendModuleRegContentNavBar',
                Data => \%Data,
            );
            # Array Element Group
            foreach my $ArrayElement qw(Group GroupRo) {
                foreach my $Index2 (1...$#{$ItemHash{Setting}[1]{FrontendModuleReg}[1]{NavBar}[$Index]{$ArrayElement}}) {                    
                    $Self->{LayoutObject}->Block(
                        Name => 'ConfigElementFrontendModuleRegContentNavBar'.$ArrayElement,
                        Data => {
                            Index => $Index,
                            ArrayIndex => $Index2,
                            ElementKey => $ItemHash{Name},
                            Content => $ItemHash{Setting}[1]{FrontendModuleReg}[1]{NavBar}[$Index]{$ArrayElement}[$Index2]{Content},
                        },
                    );
                }
            }
        }
        # NavBarModule
        if (ref($ItemHash{Setting}[1]{FrontendModuleReg}[1]{NavBarModule}) eq 'ARRAY') {
            foreach my $Index (1...$#{$ItemHash{Setting}[1]{FrontendModuleReg}[1]{NavBarModule}}) {
                my %Data = {};
                foreach my $Key qw (Module Name Block Prio) {
                    $Data{'Key'.$Key} = $Key;
                    $Data{'Content'.$Key} = '';
                    if (defined ($ItemHash{Setting}[1]{FrontendModuleReg}[1]{NavBarModule}[1]{$Key}[1]{Content})) {
                        $Data{'Content'.$Key} = $ItemHash{Setting}[1]{FrontendModuleReg}[1]{NavBarModule}[1]{$Key}[1]{Content};
                    }
                }            
                $Data{ElementKey} = $ItemHash{Name}.'#NavBarModule';
                $Self->{LayoutObject}->Block(
                    Name => 'ConfigElementFrontendModuleRegContentNavBarModule',
                    Data => \%Data,
                );
            }
        }
        elsif (defined($ItemHash{Setting}[1]{FrontendModuleReg}[1]{NavBarModule})) {
            my %Data = {};
            foreach my $Key qw (Module Name Block Prio) {
                $Data{'Key'.$Key} = $Key;
                $Data{'Content'.$Key} = '';
                if (defined ($ItemHash{Setting}[1]{FrontendModuleReg}[1]{NavBarModule}{$Key}[1]{Content})) {
                    $Data{'Content'.$Key} = $ItemHash{Setting}[1]{FrontendModuleReg}[1]{NavBarModule}{$Key}[1]{Content};
                }
            }            
            $Data{ElementKey} = $ItemHash{Name}.'#NavBarModule';
            $Self->{LayoutObject}->Block(
                Name => 'ConfigElementFrontendModuleRegContentNavBarModule',
                Data => \%Data,
            );
        }
    }
    # ConfigElement TimeVacationDaysOneTime
    elsif (defined ($ItemHash{Setting}[1]{TimeVacationDaysOneTime})) {
        $Self->{LayoutObject}->Block(
            Name => 'ConfigElementTimeVacationDaysOneTime',
            Data => {
                ElementKey => $ItemHash{Name},
            },
        );
        # New TimeVacationDaysOneTimeElement
        if ($Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#NewTimeVacationDaysOneTimeElement')) {
            push (@{$ItemHash{Setting}[1]{TimeVacationDaysOneTime}[1]{Item}}, {Key => '', Content => ''});
        }      
        # TimeVacationDaysOneTimeElements
        foreach my $Index (1...$#{$ItemHash{Setting}[1]{TimeVacationDaysOneTime}[1]{Item}}) {
            $Self->{LayoutObject}->Block(
                Name => 'ConfigElementTimeVacationDaysOneTimeContent',
                Data => {
                    ElementKey => $ItemHash{Name},
                    Year       => $ItemHash{Setting}[1]{TimeVacationDaysOneTime}[1]{Item}[$Index]{Year},
                    Month      => $ItemHash{Setting}[1]{TimeVacationDaysOneTime}[1]{Item}[$Index]{Month},
                    Day        => $ItemHash{Setting}[1]{TimeVacationDaysOneTime}[1]{Item}[$Index]{Day},
                    Content    => $ItemHash{Setting}[1]{TimeVacationDaysOneTime}[1]{Item}[$Index]{Content},                  
                    Index      => $Index,
                },
            );           
        }
    }
    # ConfigElement TimeVacationDays
    elsif (defined ($ItemHash{Setting}[1]{TimeVacationDays})) {
        $Self->{LayoutObject}->Block(
            Name => 'ConfigElementTimeVacationDays',
            Data => {
                ElementKey => $ItemHash{Name},
            },
        );
        # New TimeVacationDaysElement
        if ($Self->{ParamObject}->GetParam(Param => $ItemHash{Name}.'#NewTimeVacationDaysElement')) {
            push (@{$ItemHash{Setting}[1]{TimeVacationDays}[1]{Item}}, {Key => '', Content => ''});
        }  
        # TimeVacationDaysElements
        foreach my $Index (1...$#{$ItemHash{Setting}[1]{TimeVacationDays}[1]{Item}}) {
            $Self->{LayoutObject}->Block(
                Name => 'ConfigElementTimeVacationDaysContent',
                Data => {
                    ElementKey => $ItemHash{Name},
                    Month      => $ItemHash{Setting}[1]{TimeVacationDays}[1]{Item}[$Index]{Month},
                    Day        => $ItemHash{Setting}[1]{TimeVacationDays}[1]{Item}[$Index]{Day},
                    Content    => $ItemHash{Setting}[1]{TimeVacationDays}[1]{Item}[$Index]{Content},                  
                    Index      => $Index,
                },
            );           
        }
    }
    # ConfigElement TimeWorkingHours
    elsif (defined ($ItemHash{Setting}[1]{TimeWorkingHours})) {
        $Self->{LayoutObject}->Block(
            Name => 'ConfigElementTimeWorkingHours',
            Data => {
                ElementKey => $ItemHash{Name},
            },
        );
        # TimeWorkingHoursElements
        foreach my $Index (1...$#{$ItemHash{Setting}[1]{TimeWorkingHours}[1]{Day}}) {
            $Self->{LayoutObject}->Block(
                Name => 'ConfigElementTimeWorkingHoursContent',
                Data => {
                    ElementKey => $ItemHash{Name},
                    Weekday    => $ItemHash{Setting}[1]{TimeWorkingHours}[1]{Day}[$Index]{Name},
                    Index      => $Index,
                },
            );
            # Hours
            my @ArrayHours = ('','','','','','','','','','','','','','','','','','','','','','','','','');
            # Aktiv Hours
            if (defined($ItemHash{Setting}[1]{TimeWorkingHours}[1]{Day}[$Index]{Hour})) {
                foreach my $Index2 (1...$#{$ItemHash{Setting}[1]{TimeWorkingHours}[1]{Day}[$Index]{Hour}}) {
                    $ArrayHours[$ItemHash{Setting}[1]{TimeWorkingHours}[1]{Day}[$Index]{Hour}[$Index2]{Content}] = 'checked';
                }            
            }
            foreach my $Z (1...24) {                
                $Self->{LayoutObject}->Block(
                    Name => 'ConfigElementTimeWorkingHoursHours',
                    Data => {
                        ElementKey => $ItemHash{Name}.$ItemHash{Setting}[1]{TimeWorkingHours}[1]{Day}[$Index]{Name},
                        Hour       => $Z,
                        Aktiv      => $ArrayHours[$Z],
                    },
                );
            }          
        }
    }
}

# --
1;

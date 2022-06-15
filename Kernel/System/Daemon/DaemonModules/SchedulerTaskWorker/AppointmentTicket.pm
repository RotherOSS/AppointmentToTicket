# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/
# --
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
# --

package Kernel::System::Daemon::DaemonModules::SchedulerTaskWorker::AppointmentTicket;

use strict;
use warnings;

use parent qw(Kernel::System::Daemon::DaemonModules::BaseTaskWorker);
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CustomerUser',
    'Kernel::System::DB',
    'Kernel::System::Daemon::SchedulerDB',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::LinkObject',
    'Kernel::System::Log',
    'Kernel::System::Calendar::Appointment',
    'Kernel::System::Ticket',
    'Kernel::System::Ticket::Article',
);

=head1 NAME

Kernel::System::Daemon::DaemonModules::SchedulerTaskWorker::AppointmentTicket - Scheduler daemon task handler module for AppointmentTicket

=head1 DESCRIPTION

This task handler executes appointment ticket jobs.

=head1 PUBLIC INTERFACE

=head2 new()

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TaskHandlerObject = $Kernel::OM-Get('Kernel::System::Daemon::DaemonModules::SchedulerTaskWorker::AppointmentTicket');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug}      = $Param{Debug};
    $Self->{WorkerName} = 'Worker: AppointmentTicket';

    return $Self;
}

=head2 Run()

performs the selected task.

    my $Result = $TaskHandlerObject->Run(
        TaskID   => 123,
        TaskName => 'some name',    # optional
        Data     => {               # appointment id as got from Kernel::System::Calendar::Appointment::AppointmentGet()
            NotifyTime => '2016-08-02 03:59:00',
        },
    );

Returns:

    $Result = 1; # or fail in case of an error

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check task params
    my $CheckResult = $Self->_CheckTaskParams(
        %Param,
        NeededDataAttributes =>
            [
                'AppointmentID', 'TicketCustomerUser', 'TicketCustomerID', 'TicketUserID', 'TicketQueueID', 'TicketOwnerID',
                'TicketTitle',   'TicketSubject',      'TicketContent'
            ],
    );

    # stop execution if an error in params is detected
    return if !$CheckResult;

    my $DBObject                  = $Kernel::OM->Get('Kernel::System::DB');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $ConfigObject              = $Kernel::OM->Get('Kernel::Config');

    my $Config = $ConfigObject->Get('Ticket::Frontend::AgentAppointmentEdit');

    if ( $Self->{Debug} ) {
        print "    $Self->{WorkerName} executes task: $Param{TaskName}\n";
    }

    # fetching customer user from selectedcustomeruser
    my %CustomerUser = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
        User => $Param{Data}->{TicketSelectedCustomerUser},
    );

    # create the appointment ticket
    my $TicketID = $Kernel::OM->Get('Kernel::System::Ticket')->TicketCreate(
        QueueID      => $Param{Data}->{TicketQueueID},
        CustomerID   => $Param{Data}->{TicketCustomerID},
        CustomerUser => $CustomerUser{UserEmail},
        UserID       => $Param{Data}->{TicketUserID},
        OwnerID      => $Param{Data}->{TicketOwnerID},
        Lock         => $Param{Data}->{TicketLock},
        PriorityID   => $Param{Data}->{TicketPriorityID},
        StateID      => $Param{Data}->{TicketStateID},
        TypeID       => $Param{Data}->{TicketTypeID},
        Title        => $Param{Data}->{TicketTitle},
        Subject      => $Param{Data}->{TicketSubject},
    );

    if ( !$TicketID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Could not trigger ticket appointment for AppointmentID $Param{Data}->{AppointmentID}!",
        );
    }

    # set dynamic fields for ticket
    # Fetch dynamic field configs
    my @DynamicFieldConfigs;
    if ( defined $Config->{DynamicField} ) {
        my $DynamicFieldConfigsRef = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
            Valid       => 1,
            ObjectType  => [ 'Ticket', 'Article' ],
            FieldFilter => $Config->{DynamicField} || {},
        );   
        @DynamicFieldConfigs = defined $DynamicFieldConfigsRef ? @{ $DynamicFieldConfigsRef } : ();
    }
 
    # set ticket dynamic fields
    my %DynamicFields = %{ $Param{Data}->{TicketDynamicFields} };
    DYNAMICFIELDTICKET:
    for my $DynamicFieldConfig ( @DynamicFieldConfigs ) {
        next DYNAMICFIELDTICKET if !IsHashRefWithData($DynamicFieldConfig);
        next DYNAMICFIELDTICKET if $DynamicFieldConfig->{ObjectType} ne 'Ticket';
        if ( $DynamicFields{ $DynamicFieldConfig->{Name} } ) {
            # set the value
            my $Success = $DynamicFieldBackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $TicketID,
                Value              => $Param{Data}->{TicketDynamicFields}->{ $DynamicFieldConfig->{Name} },
                UserID             => $Param{Data}->{TicketUserID},
            );
        }
    }

    # preparing from data
    my $ArticleFrom;
    my @CustomerUsers = split( ',', $Param{Data}->{TicketCustomerUser} );
    for my $CustomerUser (@CustomerUsers) {
        my %CustomerUserData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
            User => $CustomerUser,
        );
        if ($ArticleFrom) {
            $ArticleFrom .= ", \"$CustomerUserData{UserFirstname} $CustomerUserData{UserLastname}\" <$CustomerUserData{UserEmail}>";
        }
        else {
            $ArticleFrom = "\"$CustomerUserData{UserFirstname} $CustomerUserData{UserLastname}\" <$CustomerUserData{UserEmail}>";
        }
    }

    my $ArticleObject        = $Kernel::OM->Get('Kernel::System::Ticket::Article');
    my $ArticleBackendObject = $ArticleObject->BackendForChannel( ChannelName => 'Internal' );
    my $ArticleID            = $ArticleBackendObject->ArticleCreate(
        TicketID             => $TicketID,
        SenderType           => 'system',
        IsVisibleForCustomer => $Param{Data}->{TicketArticleVisibleForCustomer} || 0,
        From                 => $ArticleFrom,
        To                   => $Param{Data}->{TicketUserID},
        Subject              => $Param{Data}->{TicketSubject},
        Body                 => $Param{Data}->{TicketContent},
        MimeType             => 'text/html',
        Charset              => 'utf-8',
        UserID               => $Param{Data}->{TicketUserID},
        HistoryType          => 'Misc',
        HistoryComment       => 'Automatically created ticket from appointment',
        AutoResponseType     => ( $ConfigObject->Get('AutoResponseForWebTickets') )
        ? 'auto reply'
        : '',
        OrigHeader => {
            From    => $ArticleFrom,
            To      => $Param{Data}->{TicketUserID},
            Subject => $Param{Data}->{TicketSubject},
            Body    => $Param{Data}->{TicketContent},
        },
        Queue => $Param{Data}->{TicketQueueID},
    );

    if ( !$ArticleID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Could not create article for ticket $TicketID from appointment $Param{Data}->{AppointmentID}!",
        );
    }

    # set article dynamic fields
    DYNAMICFIELDARTICLE:
    for my $DynamicFieldConfig ( @DynamicFieldConfigs ) {
        next DYNAMICFIELDARTICLE if !IsHashRefWithData($DynamicFieldConfig);
        next DYNAMICFIELDARTICLE if $DynamicFieldConfig->{ObjectType} ne 'Article';
        if ( $DynamicFields{ $DynamicFieldConfig->{Name} } ) {
            # set the value
            my $Success = $DynamicFieldBackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $ArticleID,
                Value              => $Param{Data}->{TicketDynamicFields}->{ $DynamicFieldConfig->{Name} },
                UserID             => $Param{Data}->{TicketUserID},
            );
        }
    }

    my %Appointment = $Kernel::OM->Get('Kernel::System::Calendar::Appointment')->AppointmentGet(
        AppointmentID => $Param{Data}->{AppointmentID},
    );

    # link the tickets
    $Kernel::OM->Get('Kernel::System::LinkObject')->LinkAdd(
        SourceObject => 'Appointment',
        SourceKey    => $Appointment{AppointmentID},
        TargetObject => 'Ticket',
        TargetKey    => $TicketID,
        Type         => 'Normal',
        State        => 'Valid',
        UserID       => $Param{Data}->{TicketUserID},
    );

    # delete future task id from appointment
    my $SQL = "
        UPDATE calendar_appointment
        SET future_task_id = NULL
        WHERE id = ?
    ";
    my @Bind = ( \$Param{Data}->{AppointmentID} );

    # update db record
    return if !$DBObject->Do(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    # Check if appointment is recurring and if so, create next future task for appointment which is in the future and closest to now
    if ( $Appointment{Recurring} || $Appointment{ParentID} ) {

        # Get all related appointments
        my @Appointments = $Kernel::OM->Get('Kernel::System::Calendar::Appointment')->AppointmentList(
            CalendarID => $Appointment{CalendarID},
            ParentID   => $Appointment{ParentID} || $Appointment{AppointmentID},
        );

        # Push parent into list since AppointmentList with filter ParentID does not include the parent itself
        my %ParentAppointment = $Kernel::OM->Get('Kernel::System::Calendar::Appointment')->AppointmentGet(
            AppointmentID => ( $Appointment{ParentID} ? $Appointment{ParentID} : $Appointment{AppointmentID} )
        );
        push @Appointments, \%ParentAppointment;

        my $CurrentTimeObject = $Kernel::OM->Create(
            'Kernel::System::DateTime'
        );

        my $NextAppointment;
        my $TimeDiff;
        my $ExecutionTime;
        for my $AppointmentRef (@Appointments) {

            my $AppointmentExecutionTimeObject = $Kernel::OM->Create(
                'Kernel::System::DateTime',
                ObjectParams => {
                    String => $Kernel::OM->Get('Kernel::System::Calendar::Appointment')->AppointmentToTicketExecutionTime(
                        Data => {
                            TicketTime                      => $Param{Data}->{TicketTime},
                            TicketTemplate                  => $Param{Data}->{TicketTemplate},
                            TicketCustom                    => $Param{Data}->{TicketCustom},
                            TicketCustomRelativeUnitCount   => $Param{Data}->{TicketCustomRelativeUnitCount},
                            TicketCustomRelativeUnit        => $Param{Data}->{TicketCustomRelativeUnit},
                            TicketCustomRelativePointOfTime => $Param{Data}->{TicketCustomRelativePointOfTime},
                            TicketCustomDateTime            => $Param{Data}->{TicketCustomDateTime},
                        },
                        StartTime => $AppointmentRef->{StartTime},
                        EndTime   => $AppointmentRef->{EndTime},
                    ),
                },
            );
            if ( $AppointmentExecutionTimeObject->Compare( DateTimeObject => $CurrentTimeObject ) > 0 ) {
                my $DeltaResult = $AppointmentExecutionTimeObject->Delta( DateTimeObject => $CurrentTimeObject );
                if ( !defined $TimeDiff ) {
                    $NextAppointment = $AppointmentRef;
                    $TimeDiff        = $DeltaResult->{AbsoluteSeconds};
                    $ExecutionTime   = $AppointmentExecutionTimeObject->ToString();
                }
                elsif ( $DeltaResult->{AbsoluteSeconds} < $TimeDiff ) {
                    $NextAppointment = $AppointmentRef;
                    $TimeDiff        = $DeltaResult->{AbsoluteSeconds};
                    $ExecutionTime   = $AppointmentExecutionTimeObject->ToString();
                }
            }
        }

        if ($NextAppointment) {
            my $FutureTaskID = $Kernel::OM->Get('Kernel::System::Daemon::SchedulerDB')->FutureTaskAdd(

                ExecutionTime => $ExecutionTime,
                Type          => 'AppointmentTicket',
                Name          => 'Test',
                Data          => {
                    TicketTitle                     => $Param{Data}->{TicketTitle},
                    TicketQueueID                   => $Param{Data}->{TicketQueueID},
                    TicketSubject                   => $Param{Data}->{TicketSubject},
                    TicketContent                   => $Param{Data}->{TicketContent},
                    TicketLock                      => 'unlock',
                    TicketTypeID                    => $Param{Data}->{TicketTypeID},
                    TicketServiceID                 => $Param{Data}->{TicketServiceID},
                    TicketSLAID                     => $Param{Data}->{TicketSLAID},
                    TicketStateID                   => $Param{Data}->{TicketStateID},
                    TicketPriorityID                => $Param{Data}->{TicketPriorityID},
                    TicketOwnerID                   => $Param{Data}->{TicketOwnerID},
                    TicketCustomerID                => $Param{Data}->{TicketCustomerID},
                    TicketCustomerUser              => $Param{Data}->{TicketCustomerUser},
                    TicketSelectedCustomerUser      => $Param{Data}->{TicketSelectedCustomerUser},
                    TicketUserID                    => $Param{Data}->{TicketUserID},
                    AppointmentID                   => $NextAppointment->{AppointmentID},
                    TicketTime                      => $Param{Data}->{TicketTime},
                    TicketTemplate                  => $Param{Data}->{TicketTemplate},
                    TicketCustom                    => $Param{Data}->{TicketCustom},
                    TicketCustomRelativeUnitCount   => $Param{Data}->{TicketCustomRelativeUnitCount},
                    TicketCustomRelativeUnit        => $Param{Data}->{TicketCustomRelativeUnit},
                    TicketCustomRelativePointOfTime => $Param{Data}->{TicketCustomRelativePointOfTime},
                    TicketCustomDateTime            => $Param{Data}->{TicketCustomDateTime},
                    TicketArticleVisibleForCustomer => $Param{Data}->{TicketArticleVisibleForCustomer},
                    TicketDynamicFields             => $Param{Data}->{TicketDynamicFields},
                }
            );

            # update appointment in db
            my $SQL = "
                UPDATE calendar_appointment
                SET future_task_id = ?
                WHERE id = ?
            ";
            my @Bind = ( \$FutureTaskID, \$NextAppointment->{AppointmentID} );

            # update db record
            return if !$DBObject->Do(
                SQL  => $SQL,
                Bind => \@Bind,
            );
        }

    }

    return $TicketID;
}

1;

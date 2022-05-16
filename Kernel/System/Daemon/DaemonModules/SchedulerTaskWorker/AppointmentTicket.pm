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

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Calendar::Appointment',
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

    use Data::Dumper;
    print STDERR "AppointmentTicket.pm, L.80: " . Dumper(\%Param) . "\n";

    # check task params
    my $CheckResult = $Self->_CheckTaskParams(
        %Param,
        NeededDataAttributes => ['CustomerUser', 'CustomerID', 'UserID', 'QueueID', 'Subject', 'Content'],
    );

    # stop execution if an error in params is detected
    return if !$CheckResult;

    if ( $Self->{Debug} ) {
        print "    $Self->{WorkerName} executes task: $Param{TaskName}\n";
    }

    # trigger the ticket appointment
    my $Success = $Kernel::OM->Get('Kernel::System::Ticket')->TicketCreate( %{ $Param{Data} } );

    if ( !$Success ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Could not trigger ticket appointment for AppointmentID $Param{Data}->{AppointmentID}!",
        );
    }

    # Check if appointment is recurring and if so, create a new appointment ticket task
    my %Appointment; # = $Kernel::OM->Get('Kernel::System::Calendar::Appointment')->AppointmentGet( 
#         AppointmentID => $Param{AppointmentID},
#     );
    
    if( $Appointment{Recurring} ) {
        # Appointment is child
        if( $Appointment{ParentID} ) {
            # Get all appointments with same title
            my @Appointments = $Kernel::OM->Get('Kernel::System::Calendar::Appointment')->AppointmentList(
                CalendarID => $Appointment{CalendarID},
                Title => $Appointment{Title}
            );

            # filter for parent id
            my @FilteredAppointments = grep( $_->{ParentID} == $Appointment{ParentID}, @Appointments );

            my @SortedFilteredAppointments = sort {$a->{AppointmentID} <=> $b->{AppointmentID}} @FilteredAppointments;
            my %NextAppointment;
            for my $AppointmentRef (@SortedFilteredAppointments) {
                my %CurrentAppointment = %{$AppointmentRef};
                if( $Appointment{AppointmentID} < $CurrentAppointment{AppointmentID} ) {
                    %NextAppointment = %CurrentAppointment;
                    last;
                }                
            }
            if( %NextAppointment ) {
                $Kernel::OM->Get()->TaskAdd(
                    ExecutionTime => $NextAppointment{StartTime},
                    Type => 'AppointmentTicket',
                    Name => 'Test',
                    Data => {
                        Title => $Param{Title},
                        QueueID => $Param{QueueID},
                        Subject => $Param{Subject},
                        Lock => 'unlock',
                        TypeID => $Param{TypeID},
                        ServiceID => $Param{ServiceID},
                        SLAID => $Param{SLAID},
                        StateID => $Param{StateID},
                        PriorityID => $Param{PriorityID},
                        OwnerID => $Param{OwnerID},
                        CustomerID => $Param{CustomerID},
                        CustomerUser => $Param{CustomerUser},
                        UserID => $Param{UserID},
                    }
                );
            }
        }
        # Appointment is parent
        else {
            # Get all appointments with same title
            my @Appointments = $Kernel::OM->Get('Kernel::System::Calendar::Appointment')->AppointmentList(
                CalendarID => $Appointment{CalendarID},
                Title => $Appointment{Title}
            );  

            # filter for parent id
            my @FilteredAppointments = grep( $_->{ParentID} == $Appointment{ParentID}, @Appointments );

            my @SortedFilteredAppointments = sort {$a->{AppointmentID} <=> $b->{AppointmentID}} @FilteredAppointments;
            my %NextAppointment = shift @SortedFilteredAppointments;
            
            if( %NextAppointment ) {
                $Kernel::OM->Get()->TaskAdd(
                    ExecutionTime => $NextAppointment{StartTime},
                    Type => 'AppointmentTicket',
                    Name => 'Test',
                    Data => {
                        # TODO Correction
                        TicketTitle => $Param{TicketTitle},
                        TicketQueueID => $Param{TicketQueueID},
                        TicketSubject => $Param{TicketSubject},
                        TicketLock => 'unlock',
                        TicketTypeID => $Param{TicketTypeID},
                        TicketServiceID => $Param{TicketServiceID},
                        TicketSLAID => $Param{TicketSLAID},
                        TicketStateID => $Param{TicketStateID},
                        TicketPriorityID => $Param{TicketPriorityID},
                        TicketOwnerID => $Param{TicketOwnerID},
                        TicketCustomerID => $Param{TicketCustomerID},
                        TicketCustomerUser => $Param{TicketCustomerUser},
                        TicketUserID => $Param{TicketUserID},
                        AppointmentID => $NextAppointment{AppointmentID},
                    }
                );
            }
        }
    }

    return $Success;
}

1;

.. toctree::
    :maxdepth: 2
    :caption: Contents

Sacrifice to Sphinx
===================

Description
===========
This package brings the functionality to automatically create a ticket with configurable parameters to a freely chooseable point in time in relation to an appointment.

The AppointmentEdit mask is extended. On the bottom, a selection 'Ticket Creation' can be found, which holds several prefixed options as well as 'Custom'. The options work analogous to the Notification options. If any other option as 'No ticket creation' is chosen, the interface expands and shows the necessary fields for creating a ticket. Note that the appointment title is taken as the ticket title and subject and that the appointment description is taken as content of the first article. The user has to choose one or more customer users, a queue, a priority level, a state and a type. Optionally, the first article, which will be created alongside the ticket, can be configured to be visible for the customer. With the system configuration option AgentAppointmentEdit###DynamicField, dynamic fields of choice can be added to the screen. 

The given data is saved and a ticket is created at the configured time. The data is not saved if the configured execution time is in the past (relative to when the form is submitted). If a recurring appointment is created, the ticket creation will be executed on the nearest appointment in the future. Once this has happened, the data is saved for the next appointment of the series, and so on.

System requirements
===================

Framework
---------
OTOBO 10.1.x

Packages
--------
\-

Third-party software
--------------------
\-

Configuration Reference
=======================

Frontend::Agent::ModuleRegistration::Loader
------------------------------------------------------------------------------------------------------------------------------

Loader::Module::AgentAppointmentCalendarOverview###009-AppointmentTicket
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Loadermodule registration for the agent interface.

Frontend::Agent::View::AgentAppointmentEdit
------------------------------------------------------------------------------------------------------------------------------

AgentAppointmentEdit###DynamicField
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Dynamic fields shown in the appointment edit screen of the agent interface

Frontend::Agent::View::TicketCalendar
------------------------------------------------------------------------------------------------------------------------------

Ticket::Frontend::AgentAppointmentEdit###StateType
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Determines the next possible ticket states, after the creation of a new ticket from a calendar appointment in the agent interface.

About
=======

Contact
-------
| Rother OSS GmbH
| Email: hello@otobo.de
| Web: https://otobo.de

Version
-------
Author: |doc-vendor| / Version: |doc-version| / Date of release: |doc-datestamp|

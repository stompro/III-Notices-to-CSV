III-Notices-to-CSV
==================

Script to convert III Millennium print overdue and bill notices to a CSV file that can be sent to a mailing outsourcer like click2mail.com.

These script take the standard overdue and bill notices send via print to email.

process-overdue-notices.pl - returns a list of patron addresses, excludes item info.  Useful for postcard overdue notices that shouldn't include item details.

process-bill-notices.pl - returns patron addresses and item information.

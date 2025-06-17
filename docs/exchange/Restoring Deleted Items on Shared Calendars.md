1. Check for recoverable items:

	* `Get-RecoverableItems -Identity "ExampleCalendar@domain.com" -FilterStartTime (Get-Date).AddDays(-7) -FilterItemType IPM.Appointment`

	* **Restore ALL deleted items:**

		* `Restore-RecoverableItems -Identity "ExampleCalendar@domain.com" -FilterStartTime (Get-Date).AddDays(-7) -FilterItemType IPM.Appointment -TargetFolder "Calendar"`

	* **Restore specific items by Subject:**

		* `Restore-RecoverableItems -Identity "ExampleCalendar@domain.com" -FilterStartTime (Get-Date).AddDays(-7) -FilterItemType IPM.Appointment -SubjectContains "TEST" -TargetFolder "Calendar"`

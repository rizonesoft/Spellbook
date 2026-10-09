param([Alias('data-dir')][string]$DataDir)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
$form=[Windows.Forms.Form]::new()
$form.Text='Spellbook UI driver fixture'
$form.Width=500; $form.Height=300
$edit=[Windows.Forms.TextBox]::new(); $edit.Name='editable'; $edit.SetBounds(20,20,300,30)
$locked=[Windows.Forms.TextBox]::new(); $locked.Name='locked'; $locked.ReadOnly=$true; $locked.Text='read only'; $locked.SetBounds(20,60,300,30)
$button=[Windows.Forms.Button]::new(); $button.Name='invoke'; $button.Text='Invoke fixture'; $button.SetBounds(20,100,150,30)
$label=[Windows.Forms.Label]::new(); $label.Name='heading'; $label.Text='Fixture ready'; $label.SetBounds(20,150,300,30)
$button.Add_Click({ $label.Text='Fixture invoked' })
$duplicate1=[Windows.Forms.Button]::new(); $duplicate1.Name='duplicate'; $duplicate1.SetBounds(340,20,100,30)
$duplicate2=[Windows.Forms.Button]::new(); $duplicate2.Name='duplicate'; $duplicate2.SetBounds(340,60,100,30)
$form.Controls.AddRange(@($edit,$locked,$button,$label,$duplicate1,$duplicate2))
$form.Add_Shown({ $edit.Focus() | Out-Null })
try { [Windows.Forms.Application]::Run($form) } finally { $form.Dispose() }

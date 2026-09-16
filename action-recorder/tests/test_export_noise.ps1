$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $PSScriptRoot '../server/recorder-server.cs') -ReferencedAssemblies 'System.Web','System.Web.Extensions'
$records=@(
'{"schema_version":2,"recording":{"id":"test"}}',
'{"opponent":{"lives":4,"nemesis_score":"10"},"after_action":0}',
'{"opponent":{"nemesis_score":"20","lives":4},"after_action":0}',
'{"opponent":{"lives":3,"nemesis_score":"30"},"after_action":0}',
'{"network":{"action":"enemyInfo","lives":4}}',
'{"network":{"lives":4,"action":"enemyInfo"}}',
'{"network":{"action":"soldJoker"}}',
'{"network":{"action":"soldJoker"}}',
'{"network":{"action":"enemyInfo","lives":3}}',
'{"network":{"action":"enemyInfo","lives":4}}',
'{"action":{"n":1,"type":"play","hand_before":[]}}',
'{"observation":{"after_action":1,"areas":{},"hand_after":[],"hand_boundary":"settled"}}',
'{"opponent":{"lives":3,"nemesis_score":"40"},"after_action":1}',
'{"opponent":{"lives":3,"nemesis_score":"50"},"after_action":1}'
)
$result=[ActionRecorderServer]::Export(($records -join "`n")+"`n")
if (($result -split 'Multiplayer after action').Count-1 -ne 3) {throw 'Score frames or state transitions incorrect'}
if ($result.Contains('"10"') -or $result.Contains('"40"') -or -not $result.Contains('"50"')) {throw 'Wrong final score'}
if (($result -split 'enemyInfo').Count-1 -ne 3) {throw 'Status duplicates or transitions incorrect'}
if (($result -split 'soldJoker').Count-1 -ne 2) {throw 'Gameplay event lost'}
if (-not $result.Contains('1. play') -or -not $result.Contains('before action 1 | hand: []') -or -not $result.Contains('after action 1 | hand: []')) {throw 'Action or hand lost'}
Write-Output 'PASS: score compression, status deduplication, transitions, repeated events, actions, hands and final flush'

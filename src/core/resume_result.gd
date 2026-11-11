class_name ResumeResult
extends RefCounted
## Outcome of `RunCheckpointer.try_resume` (M3-13).

enum Status { NONE, RESUMED, DISCARDED_DAMAGED, DISCARDED_BANKED, ENDED_BY_UPDATE }

var status: Status = Status.NONE
## RESUMED: the rebuilt world.
var world: SimWorld = null
var info: SnapshotInfo = null
## RESUMED: the extras stored in the snapshot ({} for one written without any); the run tally rides here.
var extras: Dictionary = {}
## ENDED_BY_UPDATE: the interrupted run's banked value (header text) to bank once.
var data_run: BigNum = BigNum.zero()

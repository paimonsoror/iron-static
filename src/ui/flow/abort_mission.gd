class_name AbortMission
extends RefCounted
## The pause menu's ABORT MISSION, once confirmed: ends the live run like a death (`RunController.abort_run`: banked,
## record written, snapshot cleared by the banking handlers), sends the flow BATTLE -> HOME (`AppFlow.ABORT_MISSION`,
## Results is skipped) and shows the "MISSION ABORTED: +n DATA" toast there. Pure orchestration, no state.


## True when the run was aborted. `router` may be null (tests without a screen flow).
static func run(controller: RunController, router: ScreenRouter) -> bool:
	if controller.state != RunController.State.IN_RUN or controller.world == null:
		return false
	var banks: bool = controller.banks_rewards() and controller.run_id > 0
	var earned: BigNum = controller.world.economy.data_run if banks else BigNum.zero()
	if not controller.abort_run():
		return false
	if router != null:
		@warning_ignore("return_value_discarded")
		router.dispatch(AppFlow.Event.ABORT_MISSION)
		router.show_toast(toast_text(earned), ScreenRouter.NOTICE_S)
	return true


static func toast_text(earned: BigNum) -> String:
	return Strings.fill1("home.aborted", "data", NumberFormat.format(earned))

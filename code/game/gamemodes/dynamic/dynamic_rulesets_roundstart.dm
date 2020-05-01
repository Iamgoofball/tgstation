
//////////////////////////////////////////////
//                                          //
//           SYNDICATE TRAITORS             //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/roundstart/traitor
	name = "Traitors"
	persistent = TRUE
	antag_flag = ROLE_TRAITOR
	antag_datum = /datum/antagonist/traitor/
	minimum_required_age = 0
	protected_roles = list("Prisoner","Security Officer", "Warden", "Detective", "Head of Security", "Captain")
	restricted_roles = list("Cyborg")
	required_candidates = 1
	weight = 5
	cost = 10	// Avoid raising traitor threat above 10, as it is the default low cost ruleset.
	scaling_cost = 10
	requirements = list(10,10,10,10,10,10,10,10,10,10)
	high_population_requirement = 10
	antag_cap = list(1,1,1,1,2,2,2,2,3,3)
	var/autotraitor_cooldown = 450 // 15 minutes (ticks once per 2 sec)

/datum/dynamic_ruleset/roundstart/traitor/pre_execute()
	var/num_traitors = antag_cap[indice_pop] * (scaled_times + 1)
	for (var/i = 1 to num_traitors)
		var/mob/M = pick_n_take(candidates)
		assigned += M.mind
		M.mind.special_role = ROLE_TRAITOR
		M.mind.restricted_roles = restricted_roles
		GLOB.pre_setup_antags += M.mind
	return TRUE

/datum/dynamic_ruleset/roundstart/traitor/rule_process()
	if (autotraitor_cooldown > 0)
		autotraitor_cooldown--
	else
		autotraitor_cooldown = 450 // 15 minutes
		message_admins("Checking if we can turn someone into a traitor.")
		log_game("DYNAMIC: Checking if we can turn someone into a traitor.")
		mode.picking_specific_rule(/datum/dynamic_ruleset/midround/autotraitor)

//////////////////////////////////////////
//                                      //
//           BLOOD BROTHERS             //
//                                      //
//////////////////////////////////////////

/datum/dynamic_ruleset/roundstart/traitorbro
	name = "Blood Brothers"
	antag_flag = ROLE_BROTHER
	antag_datum = /datum/antagonist/brother/
	protected_roles = list("Prisoner","Security Officer", "Warden", "Detective", "Head of Security", "Captain")
	restricted_roles = list("Cyborg", "AI")
	required_candidates = 2
	weight = 4
	cost = 15
	scaling_cost = 15
	requirements = list(40,30,30,20,20,15,15,15,10,10)
	high_population_requirement = 15
	antag_cap = list(2,2,2,2,2,2,2,2,2,2)	// Can pick 3 per team, but rare enough it doesn't matter.
	var/list/datum/team/brother_team/pre_brother_teams = list()
	var/const/min_team_size = 2

/datum/dynamic_ruleset/roundstart/traitorbro/pre_execute()
	var/num_teams = (antag_cap[indice_pop]/min_team_size) * (scaled_times + 1) // 1 team per scaling
	for(var/j = 1 to num_teams)
		if(candidates.len < min_team_size || candidates.len < required_candidates)
			break
		var/datum/team/brother_team/team = new
		var/team_size = prob(10) ? min(3, candidates.len) : 2
		for(var/k = 1 to team_size)
			var/mob/bro = pick_n_take(candidates)
			assigned += bro.mind
			team.add_member(bro.mind)
			bro.mind.special_role = "brother"
			bro.mind.restricted_roles = restricted_roles
			GLOB.pre_setup_antags += bro.mind
		pre_brother_teams += team
	return TRUE

/datum/dynamic_ruleset/roundstart/traitorbro/execute()
	for(var/datum/team/brother_team/team in pre_brother_teams)
		team.pick_meeting_area()
		team.forge_brother_objectives()
		for(var/datum/mind/M in team.members)
			M.add_antag_datum(/datum/antagonist/brother, team)
			GLOB.pre_setup_antags -= M
		team.update_name()
	mode.brother_teams += pre_brother_teams
	return TRUE

//////////////////////////////////////////////
//                                          //
//               CHANGELINGS                //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/roundstart/changeling
	name = "Changelings"
	antag_flag = ROLE_CHANGELING
	antag_datum = /datum/antagonist/changeling
	protected_roles = list("Prisoner","Security Officer", "Warden", "Detective", "Head of Security", "Captain")
	restricted_roles = list("AI", "Cyborg")
	required_candidates = 1
	weight = 3
	cost = 15
	scaling_cost = 15
	requirements = list(70,70,60,50,40,20,20,10,10,10)
	high_population_requirement = 10
	antag_cap = list(1,1,1,1,1,2,2,2,2,3)
	var/team_mode_probability = 30

/datum/dynamic_ruleset/roundstart/changeling/pre_execute()
	var/num_changelings = antag_cap[indice_pop] * (scaled_times + 1)
	for (var/i = 1 to num_changelings)
		var/mob/M = pick_n_take(candidates)
		assigned += M.mind
		M.mind.restricted_roles = restricted_roles
		M.mind.special_role = ROLE_CHANGELING
		GLOB.pre_setup_antags += M.mind
	return TRUE

/datum/dynamic_ruleset/roundstart/changeling/execute()
	var/team_mode = FALSE
	if(prob(team_mode_probability))
		team_mode = TRUE
		var/list/team_objectives = subtypesof(/datum/objective/changeling_team_objective)
		var/list/possible_team_objectives = list()
		for(var/T in team_objectives)
			var/datum/objective/changeling_team_objective/CTO = T
			if(assigned.len >= initial(CTO.min_lings))
				possible_team_objectives += T

		if(possible_team_objectives.len && prob(20*assigned.len))
			GLOB.changeling_team_objective_type = pick(possible_team_objectives)
	for(var/datum/mind/changeling in assigned)
		var/datum/antagonist/changeling/new_antag = new antag_datum()
		new_antag.team_mode = team_mode
		changeling.add_antag_datum(new_antag)
		GLOB.pre_setup_antags -= changeling
	return TRUE

//////////////////////////////////////////////
//                                          //
//               WIZARDS                    //
//                                          //
//////////////////////////////////////////////

// Dynamic is a wonderful thing that adds wizards to every round and then adds even more wizards during the round.
/datum/dynamic_ruleset/roundstart/wizard
	name = "Wizard"
	antag_flag = ROLE_WIZARD
	antag_datum = /datum/antagonist/wizard
	minimum_required_age = 14
	restricted_roles = list("Head of Security", "Captain") // Just to be sure that a wizard getting picked won't ever imply a Captain or HoS not getting drafted
	required_candidates = 1
	weight = 2
	cost = 30
	requirements = list(90,90,70,40,30,20,10,10,10,10)
	high_population_requirement = 10
	var/list/roundstart_wizards = list()

/datum/dynamic_ruleset/roundstart/wizard/acceptable(population=0, threat=0)
	if(GLOB.wizardstart.len == 0)
		log_admin("Cannot accept Wizard ruleset. Couldn't find any wizard spawn points.")
		message_admins("Cannot accept Wizard ruleset. Couldn't find any wizard spawn points.")
		return FALSE
	return ..()

/datum/dynamic_ruleset/roundstart/wizard/pre_execute()
	if(GLOB.wizardstart.len == 0)
		return FALSE
	mode.antags_rolled += 1
	var/mob/M = pick_n_take(candidates)
	if (M)
		assigned += M.mind
		M.mind.assigned_role = ROLE_WIZARD
		M.mind.special_role = ROLE_WIZARD

	return TRUE

/datum/dynamic_ruleset/roundstart/wizard/execute()
	for(var/datum/mind/M in assigned)
		M.current.forceMove(pick(GLOB.wizardstart))
		M.add_antag_datum(new antag_datum())
	return TRUE

//////////////////////////////////////////////
//                                          //
//                BLOOD CULT                //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/roundstart/bloodcult
	name = "Blood Cult"
	antag_flag = ROLE_CULTIST
	antag_datum = /datum/antagonist/cult
	minimum_required_age = 14
	restricted_roles = list("AI", "Cyborg", "Prisoner", "Security Officer", "Warden", "Detective", "Head of Security", "Captain", "Chaplain", "Head of Personnel")
	required_candidates = 2
	weight = 3
	cost = 35
	requirements = list(100,90,80,60,40,30,10,10,10,10)
	high_population_requirement = 10
	flags = HIGHLANDER_RULESET
	antag_cap = list(2,2,2,3,3,4,4,4,4,4)
	var/datum/team/cult/main_cult

/datum/dynamic_ruleset/roundstart/bloodcult/ready(forced = FALSE)
	required_candidates = antag_cap[indice_pop]
	. = ..()

/datum/dynamic_ruleset/roundstart/bloodcult/pre_execute()
	var/cultists = antag_cap[indice_pop]
	mode.antags_rolled += cultists
	for(var/cultists_number = 1 to cultists)
		if(candidates.len <= 0)
			break
		var/mob/M = pick_n_take(candidates)
		assigned += M.mind
		M.mind.special_role = ROLE_CULTIST
		M.mind.restricted_roles = restricted_roles
		GLOB.pre_setup_antags += M.mind
	return TRUE

/datum/dynamic_ruleset/roundstart/bloodcult/execute()
	main_cult = new
	for(var/datum/mind/M in assigned)
		var/datum/antagonist/cult/new_cultist = new antag_datum()
		new_cultist.cult_team = main_cult
		new_cultist.give_equipment = TRUE
		M.add_antag_datum(new_cultist)
		GLOB.pre_setup_antags -= M
	main_cult.setup_objectives()
	return TRUE

/datum/dynamic_ruleset/roundstart/bloodcult/round_result()
	..()
	if(main_cult.check_cult_victory())
		SSticker.mode_result = "win - cult win"
		SSticker.news_report = CULT_SUMMON
	else
		SSticker.mode_result = "loss - staff stopped the cult"
		SSticker.news_report = CULT_FAILURE

//////////////////////////////////////////////
//                                          //
//          NUCLEAR OPERATIVES              //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/roundstart/nuclear
	name = "Nuclear Emergency"
	antag_flag = ROLE_OPERATIVE
	antag_datum = /datum/antagonist/nukeop
	var/datum/antagonist/antag_leader_datum = /datum/antagonist/nukeop/leader
	minimum_required_age = 14
	restricted_roles = list("Head of Security", "Captain") // Just to be sure that a nukie getting picked won't ever imply a Captain or HoS not getting drafted
	required_candidates = 5
	weight = 3
	cost = 40
	requirements = list(90,90,90,80,60,40,30,20,10,10)
	high_population_requirement = 10
	flags = HIGHLANDER_RULESET
	antag_cap = list(2,2,2,3,3,3,4,4,5,5)
	var/datum/team/nuclear/nuke_team

/datum/dynamic_ruleset/roundstart/nuclear/ready(forced = FALSE)
	required_candidates = antag_cap[indice_pop]
	. = ..()

/datum/dynamic_ruleset/roundstart/nuclear/pre_execute()
	// If ready() did its job, candidates should have 5 or more members in it
	var/operatives = antag_cap[indice_pop]
	mode.antags_rolled += operatives
	for(var/operatives_number = 1 to operatives)
		if(candidates.len <= 0)
			break
		var/mob/M = pick_n_take(candidates)
		assigned += M.mind
		M.mind.assigned_role = "Nuclear Operative"
		M.mind.special_role = "Nuclear Operative"
	return TRUE

/datum/dynamic_ruleset/roundstart/nuclear/execute()
	var/leader = TRUE
	for(var/datum/mind/M in assigned)
		if (leader)
			leader = FALSE
			var/datum/antagonist/nukeop/leader/new_op = M.add_antag_datum(antag_leader_datum)
			nuke_team = new_op.nuke_team
		else
			var/datum/antagonist/nukeop/new_op = new antag_datum()
			M.add_antag_datum(new_op)
	return TRUE

/datum/dynamic_ruleset/roundstart/nuclear/round_result()
	var result = nuke_team.get_result()
	switch(result)
		if(NUKE_RESULT_FLUKE)
			SSticker.mode_result = "loss - syndicate nuked - disk secured"
			SSticker.news_report = NUKE_SYNDICATE_BASE
		if(NUKE_RESULT_NUKE_WIN)
			SSticker.mode_result = "win - syndicate nuke"
			SSticker.news_report = STATION_NUKED
		if(NUKE_RESULT_NOSURVIVORS)
			SSticker.mode_result = "halfwin - syndicate nuke - did not evacuate in time"
			SSticker.news_report = STATION_NUKED
		if(NUKE_RESULT_WRONG_STATION)
			SSticker.mode_result = "halfwin - blew wrong station"
			SSticker.news_report = NUKE_MISS
		if(NUKE_RESULT_WRONG_STATION_DEAD)
			SSticker.mode_result = "halfwin - blew wrong station - did not evacuate in time"
			SSticker.news_report = NUKE_MISS
		if(NUKE_RESULT_CREW_WIN_SYNDIES_DEAD)
			SSticker.mode_result = "loss - evacuation - disk secured - syndi team dead"
			SSticker.news_report = OPERATIVES_KILLED
		if(NUKE_RESULT_CREW_WIN)
			SSticker.mode_result = "loss - evacuation - disk secured"
			SSticker.news_report = OPERATIVES_KILLED
		if(NUKE_RESULT_DISK_LOST)
			SSticker.mode_result = "halfwin - evacuation - disk not secured"
			SSticker.news_report = OPERATIVE_SKIRMISH
		if(NUKE_RESULT_DISK_STOLEN)
			SSticker.mode_result = "halfwin - detonation averted"
			SSticker.news_report = OPERATIVE_SKIRMISH
		else
			SSticker.mode_result = "halfwin - interrupted"
			SSticker.news_report = OPERATIVE_SKIRMISH

//////////////////////////////////////////////
//                                          //
//               REVS		                //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/roundstart/revs
	name = "Revolution"
	persistent = TRUE
	antag_flag = ROLE_REV_HEAD
	antag_flag_override = ROLE_REV
	antag_datum = /datum/antagonist/rev/head
	minimum_required_age = 14
	restricted_roles = list("AI", "Cyborg", "Prisoner", "Security Officer", "Warden", "Detective", "Head of Security", "Captain", "Head of Personnel", "Chief Engineer", "Chief Medical Officer", "Research Director")
	required_candidates = 3
	weight = 2
	delay = 7 MINUTES
	cost = 35
	requirements = list(101,101,70,40,30,20,10,10,10,10)
	high_population_requirement = 10
	antag_cap = list(3,3,3,3,3,3,3,3,3,3)
	flags = HIGHLANDER_RULESET
	blocking_rules = list(/datum/dynamic_ruleset/latejoin/provocateur)
	// I give up, just there should be enough heads with 35 players...
	minimum_players = 35
	var/datum/team/revolution/revolution
	var/finished = FALSE

/datum/dynamic_ruleset/roundstart/revs/pre_execute()
	var/max_candidates = antag_cap[indice_pop]
	mode.antags_rolled += max_candidates
	for(var/i = 1 to max_candidates)
		if(candidates.len <= 0)
			break
		var/mob/M = pick_n_take(candidates)
		assigned += M.mind
		M.mind.restricted_roles = restricted_roles
		M.mind.special_role = antag_flag
		GLOB.pre_setup_antags += M.mind
	return TRUE

/datum/dynamic_ruleset/roundstart/revs/execute()
	revolution = new()
	for(var/datum/mind/M in assigned)
		GLOB.pre_setup_antags -= M
		if(check_eligible(M))
			var/datum/antagonist/rev/head/new_head = new antag_datum()
			new_head.give_flash = TRUE
			new_head.give_hud = TRUE
			new_head.remove_clumsy = TRUE
			M.add_antag_datum(new_head,revolution)
		else
			assigned -= M
			log_game("DYNAMIC: [ruletype] [name] discarded [M.name] from head revolutionary due to ineligibility.")
	if(revolution.members.len)
		revolution.update_objectives()
		revolution.update_heads()
		SSshuttle.registerHostileEnvironment(src)
		return TRUE
	log_game("DYNAMIC: [ruletype] [name] failed to get any eligible headrevs. Refunding [cost] threat.")
	return FALSE

/datum/dynamic_ruleset/roundstart/revs/clean_up()
	qdel(revolution)
	..()

/datum/dynamic_ruleset/roundstart/revs/rule_process()
	if(check_rev_victory())
		finished = REVOLUTION_VICTORY
		return RULESET_STOP_PROCESSING
	else if (check_heads_victory())
		finished = STATION_VICTORY
		SSshuttle.clearHostileEnvironment(src)
		revolution.save_members()
		for(var/datum/mind/M in revolution.members)	// Remove antag datums and prevents podcloned or exiled headrevs restarting rebellions.
			if(M.has_antag_datum(/datum/antagonist/rev/head))
				var/datum/antagonist/rev/head/R = M.has_antag_datum(/datum/antagonist/rev/head)
				R.remove_revolutionary(FALSE, "gamemode")
				if(M.current)
					var/mob/living/carbon/C = M.current
					if(istype(C) && C.stat == DEAD)
						C.makeUncloneable()
			if(M.has_antag_datum(/datum/antagonist/rev))
				var/datum/antagonist/rev/R = M.has_antag_datum(/datum/antagonist/rev)
				R.remove_revolutionary(FALSE, "gamemode")
		priority_announce("It appears the mutiny has been quelled. Please return yourself and your incapacitated colleagues to work. \
			We have remotely blacklisted the head revolutionaries in your medical records to prevent accidental revival.", null, 'sound/ai/attention.ogg', null, "Central Command Loyalty Monitoring Division")
		return RULESET_STOP_PROCESSING

/// Checks for revhead loss conditions and other antag datums.
/datum/dynamic_ruleset/roundstart/revs/proc/check_eligible(var/datum/mind/M)
	var/turf/T = get_turf(M.current)
	if(!considered_afk(M) && considered_alive(M) && is_station_level(T.z) && !M.antag_datums?.len && !HAS_TRAIT(M, TRAIT_MINDSHIELD))
		return TRUE
	return FALSE

/datum/dynamic_ruleset/roundstart/revs/check_finished()
	if(finished == REVOLUTION_VICTORY)
		return TRUE
	else
		return ..()

/datum/dynamic_ruleset/roundstart/revs/proc/check_rev_victory()
	for(var/datum/objective/mutiny/objective in revolution.objectives)
		if(!(objective.check_completion()))
			return FALSE
	return TRUE

/datum/dynamic_ruleset/roundstart/revs/proc/check_heads_victory()
	for(var/datum/mind/rev_mind in revolution.head_revolutionaries())
		var/turf/T = get_turf(rev_mind.current)
		if(!considered_afk(rev_mind) && considered_alive(rev_mind) && is_station_level(T.z))
			if(ishuman(rev_mind.current) || ismonkey(rev_mind.current))
				return FALSE
	return TRUE

/datum/dynamic_ruleset/roundstart/revs/round_result()
	if(finished == REVOLUTION_VICTORY)
		SSticker.mode_result = "win - heads killed"
		SSticker.news_report = REVS_WIN
	else if(finished == STATION_VICTORY)
		SSticker.mode_result = "loss - rev heads killed"
		SSticker.news_report = REVS_LOSE

//////////////////////////////////////////////
//                                          //
//                FAMILIES	                //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/roundstart/families
	name = "Families"
	persistent = TRUE
	antag_flag = ROLE_FAMILIES
	antag_datum = null
	minimum_required_age = 14
	restricted_roles = list("AI", "Cyborg", "Prisoner", "Security Officer", "Warden", "Detective", "Head of Security", "Captain", "Head of Personnel", "Chief Engineer", "Chief Medical Officer", "Research Director")
	required_candidates = 6
	weight = 3
	cost = 30
	requirements = list(70,60,50,40,30,20,10,10,10,10)
	high_population_requirement = 10
	antag_cap = list(6,6,6,6,6,6,6,6,6,6)
	flags = TRAITOR_RULESET // families doesn't actually force a round
	blocking_rules = list(/datum/dynamic_ruleset/midround/families)
	minimum_players = 20
	persistent = TRUE
	var/check_counter = 0
	var/endtime = null
	var/start_time = null
	var/fuckingdone = FALSE
	var/time_to_end = 60 MINUTES
	var/gangs_to_generate = 3
	var/list/gangs_to_use
	var/list/datum/mind/gangbangers = list()
	var/list/datum/mind/pigs = list()
	var/list/datum/mind/undercover_cops = list()
	var/list/gangs = list()
	var/gangs_still_alive = 0
	var/sent_announcement = FALSE
	var/list/gang_locations = list()
	var/cops_arrived = FALSE
	var/gang_balance_cap = 5
	var/wanted_level = 0

/datum/dynamic_ruleset/roundstart/families/pre_execute()
	gangs_to_use = subtypesof(/datum/antagonist/gang)
	for(var/j = 0, j < gangs_to_generate, j++)
		if (!candidates.len)
			break
		var/datum/mind/gangbanger = pick_n_take(candidates)
		gangbangers += gangbanger
		gangbanger.restricted_roles = restricted_roles
		log_game("[key_name(gangbanger)] has been selected as a starting gangster!")
		GLOB.pre_setup_antags += gangbanger.mind
	for(var/j = 0, j < gangs_to_generate, j++)
		if(!candidates.len)
			break
		var/datum/mind/one_eight_seven_on_an_undercover_cop = pick_n_take(candidates)
		pigs += one_eight_seven_on_an_undercover_cop
		undercover_cops += one_eight_seven_on_an_undercover_cop
		one_eight_seven_on_an_undercover_cop.restricted_roles = restricted_roles
		log_game("[key_name(one_eight_seven_on_an_undercover_cop)] has been selected as a starting undercover cop!")
		GLOB.pre_setup_antags += one_eight_seven_on_an_undercover_cop.mind
	endtime = world.time + time_to_end
	start_time = world.time
	return TRUE

/datum/dynamic_ruleset/roundstart/families/execute()
	var/replacement_gangsters = 0
	var/replacement_cops = 0
	for(var/datum/mind/gangbanger in gangbangers)
		if(!ishuman(gangbanger.current))
			gangbangers.Remove(gangbanger)
			log_game("DYNAMIC: [gangbanger] was not a human, and thus has lost their gangster role.")
			replacement_gangsters++
	if(replacement_gangsters)
		for(var/j = 0, j < replacement_gangsters, j++)
			if(!candidates.len)
				log_game("DYNAMIC: Unable to find more replacement gangsters. Not all of the gangs will spawn.")
				break
			var/datum/mind/gangbanger = pick_n_take(candidates)
			gangbangers += gangbanger
			log_game("DYNAMIC: [key_name(gangbanger)] has been selected as a replacement gangster!")
	for(var/datum/mind/undercover_cop in undercover_cops)
		if(!ishuman(undercover_cop.current))
			undercover_cops.Remove(undercover_cop)
			pigs.Remove(undercover_cop)
			log_game("DYNAMIC: [undercover_cop] was not a human, and thus has lost their undercover cop role.")
			replacement_cops++
	if(replacement_cops)
		for(var/j = 0, j < replacement_cops, j++)
			if(!candidates.len)
				log_game("DYNAMIC: Unable to find more replacement undercover cops. Not all of the gangs will spawn.")
				break
			var/datum/mind/undercover_cop = pick_n_take(candidates)
			undercover_cops += undercover_cop
			pigs += undercover_cop
			log_game("DYNAMIC: [key_name(undercover_cop)] has been selected as a replacement undercover cop!")
	for(var/datum/mind/undercover_cop in undercover_cops)
		var/datum/antagonist/ert/families/undercover_cop/one_eight_seven_on_an_undercover_cop = new()
		undercover_cop.add_antag_datum(one_eight_seven_on_an_undercover_cop)

	for(var/datum/mind/gangbanger in gangbangers)
		var/gang_to_use = pick_n_take(gangs_to_use)
		var/datum/antagonist/gang/new_gangster = new gang_to_use()
		var/datum/team/gang/ballas = new /datum/team/gang()
		new_gangster.my_gang = ballas
		new_gangster.starter_gangster = TRUE
		gangs += ballas
		ballas.add_member(gangbanger)
		ballas.name = new_gangster.gang_name

		ballas.acceptable_clothes = new_gangster.acceptable_clothes.Copy()
		ballas.free_clothes = new_gangster.free_clothes.Copy()
		ballas.my_gang_datum = new_gangster

		for(var/C in ballas.free_clothes)
			var/obj/O = new C(gangbanger.current)
			O.armor = list("melee" = 20, "bullet" = 20, "laser" = 20, "energy" = 20, "bomb" = 20, "bio" = 20, "rad" = 20, "fire" = 20, "acid" = 20)
			var/list/slots = list (
				"backpack" = ITEM_SLOT_BACKPACK,
				"left pocket" = ITEM_SLOT_LPOCKET,
				"right pocket" = ITEM_SLOT_RPOCKET
			)
			var/mob/living/carbon/human/H = gangbanger.current
			var/equipped = H.equip_in_one_of_slots(O, slots)
			if(!equipped)
				to_chat(gangbanger.current, "Unfortunately, you could not bring your [O] to this shift. You will need to find one.")
				qdel(O)

		gangbanger.add_antag_datum(new_gangster)
		gangbanger.current.playsound_local(gangbanger.current, 'sound/ambience/antag/thatshowfamiliesworks.ogg', 100, FALSE, pressure_affected = FALSE)
		to_chat(gangbanger.current, "<B>As you're the first gangster, your uniform and spraycan are in your inventory!</B>")
	addtimer(CALLBACK(src, .proc/announce_gang_locations), 5 MINUTES)
	addtimer(CALLBACK(src, .proc/five_minute_warning), time_to_end - 5 MINUTES)
	SSshuttle.registerHostileEnvironment(src)
	return TRUE

/datum/dynamic_ruleset/roundstart/families/rule_process()
	check_wanted_level()
	check_counter++
	if(check_counter >= 5)
		if (world.time > endtime && !fuckingdone)
			fuckingdone = TRUE
			send_in_the_fuzz()
		check_counter = 0

		check_tagged_turfs()
		check_gang_clothes()
		check_rollin_with_crews()

/datum/dynamic_ruleset/roundstart/families/proc/announce_gang_locations()
	var/list/readable_gang_names = list()
	for(var/GG in gangs)
		var/datum/team/gang/G = GG
		readable_gang_names += "[G.name]"
	var/finalized_gang_names = english_list(readable_gang_names)
	priority_announce("Julio G coming to you live from Radio Los Spess! We've been hearing reports of gang activity on [station_name()], with the [finalized_gang_names] duking it out, looking for fresh territory and drugs to sling! Stay safe out there for the hour 'till the space cops get there, and keep it cool, yeah?\n\n The local jump gates are shut down for about an hour due to some maintenance troubles, so if you wanna split from the area you're gonna have to wait an hour. \n Play music, not gunshots, I say. Peace out!", "Radio Los Spess", 'sound/voice/beepsky/radio.ogg')
	sent_announcement = TRUE

/datum/dynamic_ruleset/roundstart/families/proc/five_minute_warning()
	priority_announce("Julio G coming to you live from Radio Los Spess! The space cops are closing in on [station_name()] and will arrive in about 5 minutes! Better clear on out of there if you don't want to get hurt!", "Radio Los Spess", 'sound/voice/beepsky/radio.ogg')


/datum/dynamic_ruleset/roundstart/families/round_result()
	var/alive_gangsters = 0
	var/alive_cops = 0
	for(var/datum/mind/gangbanger in gangbangers)
		if(!ishuman(gangbanger.current))
			continue
		var/mob/living/carbon/human/H = gangbanger.current
		if(H.stat)
			continue
		alive_gangsters++
	for(var/datum/mind/bacon in pigs)
		if(!ishuman(bacon.current)) // always returns false
			continue
		var/mob/living/carbon/human/H = bacon.current
		if(H.stat)
			continue
		alive_cops++
	if(alive_gangsters > alive_cops)
		SSticker.mode_result = "win - gangs survived"
		SSticker.news_report = GANG_OPERATING
		return TRUE
	SSticker.mode_result = "loss - police destroyed the gangs"
	SSticker.news_report = GANG_DESTROYED
	return FALSE

///Checks if our wanted level has changed. Only actually does something post the initial announcement and until the cops are here. After that its locked.
/datum/dynamic_ruleset/roundstart/families/proc/check_wanted_level()
	if(!sent_announcement || cops_arrived)
		return
	var/new_wanted_level
	if(GLOB.joined_player_list.len > LOWPOP_FAMILIES_COUNT)
		switch(GLOB.deaths_during_shift)
			if(0 to TWO_STARS_HIGHPOP-1)
				new_wanted_level = 1
			if(TWO_STARS_HIGHPOP to THREE_STARS_HIGHPOP-1)
				new_wanted_level = 2
			if(THREE_STARS_HIGHPOP to FOUR_STARS_HIGHPOP-1)
				new_wanted_level = 3
			if(FOUR_STARS_HIGHPOP to FIVE_STARS_HIGHPOP-1)
				new_wanted_level = 4
			if(FIVE_STARS_HIGHPOP to INFINITY)
				new_wanted_level = 5
	else
		switch(GLOB.deaths_during_shift)
			if(0 to TWO_STARS_LOW-1)
				new_wanted_level = 1
			if(TWO_STARS_LOW to THREE_STARS_LOW-1)
				new_wanted_level = 2
			if(THREE_STARS_LOW to FOUR_STARS_LOW-1)
				new_wanted_level = 3
			if(FOUR_STARS_LOW to FIVE_STARS_LOW-1)
				new_wanted_level = 4
			if(FIVE_STARS_LOW to INFINITY)
				new_wanted_level = 5
	update_wanted_level(new_wanted_level)

///Updates the icon states for everyone and sends outs announcements regarding the police.
/datum/dynamic_ruleset/roundstart/families/proc/update_wanted_level(newlevel)
	if(newlevel > wanted_level)
		on_gain_wanted_level(newlevel)
	else if (newlevel < wanted_level)
		on_lower_wanted_level(newlevel)
	wanted_level = newlevel
	for(var/i in GLOB.player_list)
		var/mob/M = i
		if(!M.hud_used?.wanted_lvl)
			continue
		var/datum/hud/H = M.hud_used
		H.wanted_lvl.level = newlevel
		H.wanted_lvl.cops_arrived = cops_arrived
		H.wanted_lvl.update_icon()

/datum/dynamic_ruleset/roundstart/families/proc/on_gain_wanted_level(newlevel)
	var/announcement_message
	switch(newlevel)
		if(2)
			announcement_message = "Small amount of police vehicles have been spotted en route towards [station_name()]. They will arrive at the 50 minute mark."
			endtime = start_time + 50 MINUTES
		if(3)
			announcement_message = "A large detachment police vehicles have been spotted en route towards [station_name()]. They will arrive at the 40 minute mark."
			endtime = start_time + 40 MINUTES
		if(4)
			announcement_message = "A detachment of top-trained agents has been spotted on their way to [station_name()]. They will arrive at the 35 minute mark."
			endtime = start_time + 35 MINUTES
		if(5)
			announcement_message = "The fleet enroute to [station_name()] now consists of national guard personnel. They will arrive at the 30 minute mark."
			endtime = start_time + 30 MINUTES
	priority_announce(announcement_message, "Station Spaceship Detection Systems")

/datum/dynamic_ruleset/roundstart/families/proc/on_lower_wanted_level(newlevel)
	var/announcement_message
	switch(newlevel)
		if(1)
			announcement_message = "There are now only a few police vehicle headed towards [station_name()]. They will arrive at the 60 minute mark."
			endtime = start_time + 60 MINUTES
		if(2)
			announcement_message = "There seem to be fewer police vehicles headed towards [station_name()]. They will arrive at the 50 minute mark."
			endtime = start_time + 50 MINUTES
		if(3)
			announcement_message = "There are no longer top-trained agents in the fleet headed towards [station_name()]. They will arrive at the 40 minute mark."
			endtime = start_time + 40 MINUTES
		if(4)
			announcement_message = "The convoy enroute to [station_name()] seems to no longer consist of national guard personnel. They will arrive at the 35 minute mark."
			endtime = start_time + 35 MINUTES
	priority_announce(announcement_message, "Station Spaceship Detection Systems")

/datum/dynamic_ruleset/roundstart/families/proc/send_in_the_fuzz()
	var/team_size
	var/cops_to_send
	var/announcement_message = "PUNK ASS BALLA BITCH"
	var/announcer = "Spinward Stellar Coalition"
	if(GLOB.joined_player_list.len > LOWPOP_FAMILIES_COUNT)
		switch(wanted_level)
			if(1)
				team_size = 8
				cops_to_send = /datum/antagonist/ert/families/beatcop
				announcement_message = "Hello, crewmembers of [station_name()]! We've received a few calls about some potential violent gang activity on board your station, so we're sending some beat cops to check things out. Nothing extreme, just a courtesy call. However, while they check things out for about 10 minutes, we're going to have to ask that you keep your escape shuttle parked.\n\nHave a pleasant day!"
				announcer = "Spinward Stellar Coalition Police Department"
			if(2)
				team_size = 9
				cops_to_send = /datum/antagonist/ert/families/beatcop/armored
				announcement_message = "Crewmembers of [station_name()]. We have received confirmed reports of violent gang activity from your station. We are dispatching some armed officers to help keep the peace and investigate matters. Do not get in their way, and comply with any and all requests from them. We have blockaded the local warp gate, and your shuttle cannot depart for another 10 minutes.\n\nHave a secure day."
				announcer = "Spinward Stellar Coalition Police Department"
			if(3)
				team_size = 10
				cops_to_send = /datum/antagonist/ert/families/beatcop/swat
				announcement_message = "Crewmembers of [station_name()]. We have received confirmed reports of extreme gang activity from your station resulting in heavy civilian casualties. The Spinward Stellar Coalition does not tolerate abuse towards our citizens, and we will be responding in force to keep the peace and reduce civilian casualties. We have your station surrounded, and all gangsters must drop their weapons and surrender peacefully.\n\nHave a secure day."
				announcer = "Spinward Stellar Coalition Police Department"
			if(4)
				team_size = 11
				cops_to_send = /datum/antagonist/ert/families/beatcop/fbi
				announcement_message = "We are dispatching our top agents to [station_name()] at the request of the Spinward Stellar Coalition government due to an extreme terrorist level threat against this Nanotrasen owned station. All gangsters must surrender IMMEDIATELY. Failure to comply can and will result in death. We have blockaded your warp gates and will not allow any escape until the situation is resolved within our standard response time of 10 minutes.\n\nSurrender now or face the consequences of your actions."
				announcer = "Federal Bureau of Investigation"
			if(5)
				team_size = 12
				cops_to_send = /datum/antagonist/ert/families/beatcop/military
				announcement_message = "Due to an insane level of civilian casualties aboard [station_name()], we have dispatched the National Guard to curb any and all gang activity on board the station. We have heavy cruisers watching the shuttle. Attempt to leave before we allow you to, and we will obliterate your station and your escape shuttle.\n\nYou brought this on yourselves by murdering so many civilians."
				announcer = "Spinward Stellar Coalition National Guard"
	else
		switch(wanted_level)
			if(1)
				team_size = 5
				cops_to_send = /datum/antagonist/ert/families/beatcop
				announcement_message = "Hello, crewmembers of [station_name()]! We've received a few calls about some potential violent gang activity on board your station, so we're sending some beat cops to check things out. Nothing extreme, just a courtesy call. However, while they check things out for about 10 minutes, we're going to have to ask that you keep your escape shuttle parked.\n\nHave a pleasant day!"
				announcer = "Spinward Stellar Coalition Police Department"
			if(2)
				team_size = 6
				cops_to_send = /datum/antagonist/ert/families/beatcop/armored
				announcement_message = "Crewmembers of [station_name()]. We have received confirmed reports of violent gang activity from your station. We are dispatching some armed officers to help keep the peace and investigate matters. Do not get in their way, and comply with any and all requests from them. We have blockaded the local warp gate, and your shuttle cannot depart for another 10 minutes.\n\nHave a secure day."
				announcer = "Spinward Stellar Coalition Police Department"
			if(3)
				team_size = 7
				cops_to_send = /datum/antagonist/ert/families/beatcop/swat
				announcement_message = "Crewmembers of [station_name()]. We have received confirmed reports of extreme gang activity from your station resulting in heavy civilian casualties. The Spinward Stellar Coalition does not tolerate abuse towards our citizens, and we will be responding in force to keep the peace and reduce civilian casualties. We have your station surrounded, and all gangsters must drop their weapons and surrender peacefully.\n\nHave a secure day."
				announcer = "Spinward Stellar Coalition Police Department"
			if(4)
				team_size = 8
				cops_to_send = /datum/antagonist/ert/families/beatcop/fbi
				announcement_message = "We are dispatching our top agents to [station_name()] at the request of the Spinward Stellar Coalition government due to an extreme terrorist level threat against this Nanotrasen owned station. All gangsters must surrender IMMEDIATELY. Failure to comply can and will result in death. We have blockaded your warp gates and will not allow any escape until the situation is resolved within our standard response time of 10 minutes.\n\nSurrender now or face the consequences of your actions."
				announcer = "Federal Bureau of Investigation"
			if(5)
				team_size = 10
				cops_to_send = /datum/antagonist/ert/families/beatcop/military
				announcement_message = "Due to an insane level of civilian casualties aboard [station_name()], we have dispatched the National Guard to curb any and all gang activity on board the station. We have heavy cruisers watching the shuttle. Attempt to leave before we allow you to, and we will obliterate your station and your escape shuttle.\n\nYou brought this on yourselves by murdering so many civilians."
				announcer = "Spinward Stellar Coalition National Guard"

	priority_announce(announcement_message, announcer, 'sound/effects/families_police.ogg')
	var/list/mob/dead/observer/candidates = pollGhostCandidates("Do you want to help clean up crime on this station?", "deathsquad", null)


	if(candidates.len)
		//Pick the (un)lucky players
		var/numagents = min(team_size,candidates.len)

		var/list/spawnpoints = GLOB.emergencyresponseteamspawn
		var/index = 0
		while(numagents && candidates.len)
			var/spawnloc = spawnpoints[index+1]
			//loop through spawnpoints one at a time
			index = (index + 1) % spawnpoints.len
			var/mob/dead/observer/chosen_candidate = pick(candidates)
			candidates -= chosen_candidate
			if(!chosen_candidate.key)
				continue

			//Spawn the body
			var/mob/living/carbon/human/cop = new(spawnloc)
			chosen_candidate.client.prefs.copy_to(cop)
			cop.key = chosen_candidate.key

			//Give antag datum
			var/datum/antagonist/ert/ert_antag = new cops_to_send

			cop.mind.add_antag_datum(ert_antag)
			cop.mind.assigned_role = ert_antag.name
			SSjob.SendToLateJoin(cop)

			//Logging and cleanup
			log_game("[key_name(cop)] has been selected as an [ert_antag.name]")
			numagents--
	cops_arrived = TRUE
	update_wanted_level() //Will make sure our icon updates properly
	addtimer(CALLBACK(src, .proc/end_hostile_sit), 10 MINUTES)
	return TRUE

/datum/dynamic_ruleset/roundstart/families/proc/end_hostile_sit()
	SSshuttle.clearHostileEnvironment(src)


/datum/dynamic_ruleset/roundstart/families/proc/check_tagged_turfs()
	for(var/T in GLOB.gang_tags)
		var/obj/effect/decal/cleanable/crayon/gang/tag = T
		if(tag.my_gang)
			tag.my_gang.adjust_points(50)
		CHECK_TICK

/datum/dynamic_ruleset/roundstart/families/proc/check_gang_clothes() // TODO: make this grab the sprite itself, average out what the primary color would be, then compare how close it is to the gang color so I don't have to manually fill shit out for 5 years for every gang type
	for(var/mob/living/carbon/human/H in GLOB.player_list)
		if(!H.mind || !H.client)
			continue
		var/datum/antagonist/gang/is_gangster = H.mind.has_antag_datum(/datum/antagonist/gang)
		for(var/clothing in list(H.head, H.wear_mask, H.wear_suit, H.w_uniform, H.back, H.gloves, H.shoes, H.belt, H.s_store, H.glasses, H.ears, H.wear_id))
			if(is_gangster)
				if(is_type_in_list(clothing, is_gangster.acceptable_clothes))
					is_gangster.add_gang_points(10)
			else
				for(var/G in gangs)
					var/datum/team/gang/gang_clothes = G
					if(is_type_in_list(clothing, gang_clothes.acceptable_clothes))
						gang_clothes.adjust_points(5)

		CHECK_TICK

/datum/dynamic_ruleset/roundstart/families/proc/check_rollin_with_crews()
	var/list/areas_to_check = list()
	for(var/G in gangbangers)
		var/datum/mind/gangster = G
		areas_to_check += get_area(gangster.current)
	for(var/AA in areas_to_check)
		var/area/A = AA
		var/list/gang_members = list()
		for(var/mob/living/carbon/human/H in A)
			if(H.stat || !H.mind || !H.client)
				continue
			var/datum/antagonist/gang/is_gangster = H.mind.has_antag_datum(/datum/antagonist/gang)
			if(is_gangster)
				gang_members[is_gangster.my_gang]++
			CHECK_TICK
		if(gang_members.len)
			for(var/datum/team/gang/gangsters in gang_members)
				if(gang_members[gangsters] >= CREW_SIZE_MIN)
					if(gang_members[gangsters] >= CREW_SIZE_MAX)
						gangsters.adjust_points(5) // Discourage larger clumps, spread ur people out
					else
						gangsters.adjust_points(10)


// Admin only rulesets. The threat requirement is 101 so it is not possible to roll them.

//////////////////////////////////////////////
//                                          //
//               EXTENDED                   //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/roundstart/extended
	name = "Extended"
	antag_flag = null
	antag_datum = null
	restricted_roles = list()
	required_candidates = 0
	weight = 3
	cost = 0
	requirements = list(101,101,101,101,101,101,101,101,101,101)
	high_population_requirement = 101

/datum/dynamic_ruleset/roundstart/extended/pre_execute()
	message_admins("Starting a round of extended.")
	log_game("Starting a round of extended.")
	mode.spend_threat(mode.threat)
	mode.threat_log += "[worldtime2text()]: Extended ruleset set threat to 0."
	return TRUE

//////////////////////////////////////////////
//                                          //
//               CLOWN OPS                  //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/roundstart/nuclear/clown_ops
	name = "Clown Ops"
	antag_datum = /datum/antagonist/nukeop/clownop
	antag_leader_datum = /datum/antagonist/nukeop/leader/clownop
	requirements = list(101,101,101,101,101,101,101,101,101,101)
	high_population_requirement = 101

/datum/dynamic_ruleset/roundstart/nuclear/clown_ops/pre_execute()
	. = ..()
	if(.)
		for(var/obj/machinery/nuclearbomb/syndicate/S in GLOB.nuke_list)
			var/turf/T = get_turf(S)
			if(T)
				qdel(S)
				new /obj/machinery/nuclearbomb/syndicate/bananium(T)
		for(var/datum/mind/V in assigned)
			V.assigned_role = "Clown Operative"
			V.special_role = "Clown Operative"

//////////////////////////////////////////////
//                                          //
//               DEVIL                      //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/roundstart/devil
	name = "Devil"
	antag_flag = ROLE_DEVIL
	antag_datum = /datum/antagonist/devil
	restricted_roles = list("Lawyer", "Curator", "Chaplain", "Prisoner", "Head of Security", "Captain", "AI")
	required_candidates = 1
	weight = 3
	cost = 0
	requirements = list(101,101,101,101,101,101,101,101,101,101)
	high_population_requirement = 101
	antag_cap = list(1,1,1,2,2,2,3,3,3,4)

/datum/dynamic_ruleset/roundstart/devil/pre_execute()
	var/num_devils = antag_cap[indice_pop]
	mode.antags_rolled += num_devils

	for(var/j = 0, j < num_devils, j++)
		if (!candidates.len)
			break
		var/mob/devil = pick_n_take(candidates)
		assigned += devil.mind
		devil.mind.special_role = ROLE_DEVIL
		devil.mind.restricted_roles = restricted_roles
		GLOB.pre_setup_antags += devil.mind

		log_game("[key_name(devil)] has been selected as a devil")
	return TRUE

/datum/dynamic_ruleset/roundstart/devil/execute()
	for(var/datum/mind/devil in assigned)
		add_devil(devil.current, ascendable = TRUE)
		GLOB.pre_setup_antags -= devil
		add_devil_objectives(devil,2)
	return TRUE

/datum/dynamic_ruleset/roundstart/devil/proc/add_devil_objectives(datum/mind/devil_mind, quantity)
	var/list/validtypes = list(/datum/objective/devil/soulquantity, /datum/objective/devil/soulquality, /datum/objective/devil/sintouch, /datum/objective/devil/buy_target)
	var/datum/antagonist/devil/D = devil_mind.has_antag_datum(/datum/antagonist/devil)
	for(var/i = 1 to quantity)
		var/type = pick(validtypes)
		var/datum/objective/devil/objective = new type(null)
		objective.owner = devil_mind
		D.objectives += objective
		if(!istype(objective, /datum/objective/devil/buy_target))
			validtypes -= type
		else
			objective.find_target()

//////////////////////////////////////////////
//                                          //
//               MONKEY                     //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/roundstart/monkey
	name = "Monkey"
	antag_flag = ROLE_MONKEY
	antag_datum = /datum/antagonist/monkey/leader
	restricted_roles = list("Cyborg", "AI", "Prisoner")
	required_candidates = 1
	weight = 3
	cost = 0
	requirements = list(101,101,101,101,101,101,101,101,101,101)
	high_population_requirement = 101
	var/players_per_carrier = 30
	var/monkeys_to_win = 1
	var/escaped_monkeys = 0
	var/datum/team/monkey/monkey_team

/datum/dynamic_ruleset/roundstart/monkey/pre_execute()
	var/carriers_to_make = max(round(mode.roundstart_pop_ready / players_per_carrier, 1), 1)
	mode.antags_rolled += carriers_to_make

	for(var/j = 0, j < carriers_to_make, j++)
		if (!candidates.len)
			break
		var/mob/carrier = pick_n_take(candidates)
		assigned += carrier.mind
		carrier.mind.special_role = "Monkey Leader"
		carrier.mind.restricted_roles = restricted_roles
		log_game("[key_name(carrier)] has been selected as a Jungle Fever carrier")
	return TRUE

/datum/dynamic_ruleset/roundstart/monkey/execute()
	for(var/datum/mind/carrier in assigned)
		var/datum/antagonist/monkey/M = add_monkey_leader(carrier)
		if(M)
			monkey_team = M.monkey_team
	return TRUE

/datum/dynamic_ruleset/roundstart/monkey/proc/check_monkey_victory()
	if(SSshuttle.emergency.mode != SHUTTLE_ENDGAME)
		return FALSE
	var/datum/disease/D = new /datum/disease/transformation/jungle_fever()
	for(var/mob/living/carbon/monkey/M in GLOB.alive_mob_list)
		if (M.HasDisease(D))
			if(M.onCentCom() || M.onSyndieBase())
				escaped_monkeys++
	if(escaped_monkeys >= monkeys_to_win)
		return TRUE
	else
		return FALSE

// This does not get called. Look into making it work.
/datum/dynamic_ruleset/roundstart/monkey/round_result()
	if(check_monkey_victory())
		SSticker.mode_result = "win - monkey win"
	else
		SSticker.mode_result = "loss - staff stopped the monkeys"

//////////////////////////////////////////////
//                                          //
//               METEOR                     //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/roundstart/meteor
	name = "Meteor"
	persistent = TRUE
	required_candidates = 0
	weight = 3
	cost = 0
	requirements = list(101,101,101,101,101,101,101,101,101,101)
	high_population_requirement = 101
	var/meteordelay = 2000
	var/nometeors = 0
	var/rampupdelta = 5

/datum/dynamic_ruleset/roundstart/meteor/rule_process()
	if(nometeors || meteordelay > world.time - SSticker.round_start_time)
		return

	var/list/wavetype = GLOB.meteors_normal
	var/meteorminutes = (world.time - SSticker.round_start_time - meteordelay) / 10 / 60

	if (prob(meteorminutes))
		wavetype = GLOB.meteors_threatening

	if (prob(meteorminutes/2))
		wavetype = GLOB.meteors_catastrophic

	var/ramp_up_final = clamp(round(meteorminutes/rampupdelta), 1, 10)

	spawn_meteors(ramp_up_final, wavetype)

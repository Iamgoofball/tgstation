//////////////////////////////////////////////
//                                          //
//            MIDROUND RULESETS             //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround // Can be drafted once in a while during a round
	ruletype = "Midround"
	/// If the ruleset should be restricted from ghost roles.
	var/restrict_ghost_roles = TRUE
	/// What mob type the ruleset is restricted to.
	var/required_type = /mob/living/carbon/human
	var/list/living_players = list()
	var/list/living_antags = list()
	var/list/dead_players = list()
	var/list/list_observers = list()

/datum/dynamic_ruleset/midround/from_ghosts
	weight = 0
	required_type = /mob/dead/observer
	/// Whether the ruleset should call generate_ruleset_body or not.
	var/makeBody = TRUE

/datum/dynamic_ruleset/midround/trim_candidates()
	living_players = trim_list(mode.current_players[CURRENT_LIVING_PLAYERS])
	living_antags = trim_list(mode.current_players[CURRENT_LIVING_ANTAGS])
	dead_players = trim_list(mode.current_players[CURRENT_DEAD_PLAYERS])
	list_observers = trim_list(mode.current_players[CURRENT_OBSERVERS])

/datum/dynamic_ruleset/midround/proc/trim_list(list/L = list())
	var/list/trimmed_list = L.Copy()
	for(var/mob/M in trimmed_list)
		if (!istype(M, required_type))
			trimmed_list.Remove(M)
			continue
		if (!M.client) // Are they connected?
			trimmed_list.Remove(M)
			continue
		if(!mode.check_age(M.client, minimum_required_age))
			trimmed_list.Remove(M)
			continue
		if(antag_flag_override)
			if(!(antag_flag_override in M.client.prefs.be_special) || is_banned_from(M.ckey, list(antag_flag_override, ROLE_SYNDICATE)))
				trimmed_list.Remove(M)
				continue
		else
			if(!(antag_flag in M.client.prefs.be_special) || is_banned_from(M.ckey, list(antag_flag, ROLE_SYNDICATE)))
				trimmed_list.Remove(M)
				continue
		if (M.mind)
			if (restrict_ghost_roles && (M.mind.assigned_role in GLOB.exp_specialmap[EXP_TYPE_SPECIAL])) // Are they playing a ghost role?
				trimmed_list.Remove(M)
				continue
			if (M.mind.assigned_role in restricted_roles) // Does their job allow it?
				trimmed_list.Remove(M)
				continue
			if ((exclusive_roles.len > 0) && !(M.mind.assigned_role in exclusive_roles)) // Is the rule exclusive to their job?
				trimmed_list.Remove(M)
				continue
	return trimmed_list

// You can then for example prompt dead players in execute() to join as strike teams or whatever
// Or autotator someone

// IMPORTANT, since /datum/dynamic_ruleset/midround may accept candidates from both living, dead, and even antag players, you need to manually check whether there are enough candidates
// (see /datum/dynamic_ruleset/midround/autotraitor/ready(var/forced = FALSE) for example)
/datum/dynamic_ruleset/midround/ready(forced = FALSE)
	if (!forced)
		var/job_check = 0
		if (enemy_roles.len > 0)
			for (var/mob/M in mode.current_players[CURRENT_LIVING_PLAYERS])
				if (M.stat == DEAD || !M.client)
					continue // Dead/disconnected players cannot count as opponents
				if (M.mind && M.mind.assigned_role && (M.mind.assigned_role in enemy_roles) && (!(M in candidates) || (M.mind.assigned_role in restricted_roles)))
					job_check++ // Checking for "enemies" (such as sec officers). To be counters, they must either not be candidates to that rule, or have a job that restricts them from it

		var/threat = round(mode.threat_level/10)
		if (job_check < required_enemies[threat])
			return FALSE
	return TRUE

/datum/dynamic_ruleset/midround/from_ghosts/execute()
	var/list/possible_candidates = list()
	possible_candidates.Add(dead_players)
	possible_candidates.Add(list_observers)
	send_applications(possible_candidates)
	if(assigned.len > 0)
		return TRUE
	else
		return FALSE

/// This sends a poll to ghosts if they want to be a ghost spawn from a ruleset.
/datum/dynamic_ruleset/midround/from_ghosts/proc/send_applications(list/possible_volunteers = list())
	if (possible_volunteers.len <= 0) // This shouldn't happen, as ready() should return FALSE if there is not a single valid candidate
		message_admins("Possible volunteers was 0. This shouldn't appear, because of ready(), unless you forced it!")
		return
	message_admins("Polling [possible_volunteers.len] players to apply for the [name] ruleset.")
	log_game("DYNAMIC: Polling [possible_volunteers.len] players to apply for the [name] ruleset.")

	candidates = pollGhostCandidates("The mode is looking for volunteers to become [antag_flag] for [name]", antag_flag, SSticker.mode, antag_flag_override ? antag_flag_override : antag_flag, poll_time = 300)

	if(!candidates || candidates.len <= 0)
		message_admins("The ruleset [name] received no applications.")
		log_game("DYNAMIC: The ruleset [name] received no applications.")
		mode.executed_rules -= src
		return

	message_admins("[candidates.len] players volunteered for the ruleset [name].")
	log_game("DYNAMIC: [candidates.len] players volunteered for [name].")
	review_applications()

/// Here is where you can check if your ghost applicants are valid for the ruleset.
/// Called by send_applications().
/datum/dynamic_ruleset/midround/from_ghosts/proc/review_applications()
	for (var/i = 1, i <= required_candidates, i++)
		if(candidates.len <= 0)
			if(i == 1)
				// We have found no candidates so far and we are out of applicants.
				mode.executed_rules -= src
			break
		var/mob/applicant = pick(candidates)
		candidates -= applicant
		if(!isobserver(applicant))
			if(applicant.stat == DEAD) // Not an observer? If they're dead, make them one.
				applicant = applicant.ghostize(FALSE)
			else // Not dead? Disregard them, pick a new applicant
				i--
				continue

		if(!applicant)
			i--
			continue

		var/mob/new_character = applicant

		if (makeBody)
			new_character = generate_ruleset_body(applicant)

		finish_setup(new_character, i)
		assigned += applicant
		notify_ghosts("[new_character] has been picked for the ruleset [name]!", source = new_character, action = NOTIFY_ORBIT, header="Something Interesting!")

/datum/dynamic_ruleset/midround/from_ghosts/proc/generate_ruleset_body(mob/applicant)
	var/mob/living/carbon/human/new_character = makeBody(applicant)
	new_character.dna.remove_all_mutations()
	return new_character

/datum/dynamic_ruleset/midround/from_ghosts/proc/finish_setup(mob/new_character, index)
	var/datum/antagonist/new_role = new antag_datum()
	setup_role(new_role)
	new_character.mind.add_antag_datum(new_role)
	new_character.mind.special_role = antag_flag

/datum/dynamic_ruleset/midround/from_ghosts/proc/setup_role(datum/antagonist/new_role)
	return

//////////////////////////////////////////////
//                                          //
//           SYNDICATE TRAITORS             //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/autotraitor
	name = "Syndicate Sleeper Agent"
	antag_datum = /datum/antagonist/traitor
	antag_flag = ROLE_TRAITOR
	protected_roles = list("Prisoner", "Security Officer", "Warden", "Detective", "Head of Security", "Captain")
	restricted_roles = list("Cyborg", "AI", "Positronic Brain")
	required_candidates = 1
	weight = 7
	cost = 10
	requirements = list(50,40,30,20,10,10,10,10,10,10)
	repeatable = TRUE
	high_population_requirement = 10
	flags = TRAITOR_RULESET


/datum/dynamic_ruleset/midround/autotraitor/acceptable(population = 0, threat = 0)
	var/player_count = mode.current_players[CURRENT_LIVING_PLAYERS].len
	var/antag_count = mode.current_players[CURRENT_LIVING_ANTAGS].len
	var/max_traitors = round(player_count / 10) + 1
	if ((antag_count < max_traitors) && prob(mode.threat_level))//adding traitors if the antag population is getting low
		return ..()
	else
		return FALSE

/datum/dynamic_ruleset/midround/autotraitor/trim_candidates()
	..()
	for(var/mob/living/player in living_players)
		if(issilicon(player)) // Your assigned role doesn't change when you are turned into a silicon.
			living_players -= player
			continue
		if(is_centcom_level(player.z))
			living_players -= player // We don't autotator people in CentCom
			continue
		if(player.mind && (player.mind.special_role || player.mind.antag_datums?.len > 0))
			living_players -= player // We don't autotator people with roles already

/datum/dynamic_ruleset/midround/autotraitor/ready(forced = FALSE)
	if (required_candidates > living_players.len)
		return FALSE
	return ..()

/datum/dynamic_ruleset/midround/autotraitor/execute()
	var/mob/M = pick(living_players)
	assigned += M
	living_players -= M
	var/datum/antagonist/traitor/newTraitor = new
	M.mind.add_antag_datum(newTraitor)
	return TRUE

/datum/dynamic_ruleset/midround/families
	name = "Families Uprising"
	antag_flag = ROLE_FAMILIES
	protected_roles = list("Prisoner", "Security Officer", "Warden", "Detective", "Head of Security", "Captain")
	restricted_roles = list("Prisoner", "Security Officer", "Warden", "Detective", "Head of Security", "Captain", "Cyborg", "AI", "Positronic Brain")
	required_candidates = 6
	weight = 5
	cost = 20
	requirements = list(50,40,30,20,10,10,10,10,10,10)
	blocking_rules = list(/datum/dynamic_ruleset/roundstart/families)
	high_population_requirement = 10
	persistent = TRUE
	flags = TRAITOR_RULESET
	var/check_counter = 0
	var/endtime = null
	var/start_time = null
	var/fuckingdone = FALSE
	var/time_to_end = 30 MINUTES
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

/datum/dynamic_ruleset/midround/families/trim_candidates()
	..()
	for(var/mob/living/player in living_players)
		if(issilicon(player)) // Your assigned role doesn't change when you are turned into a silicon.
			living_players -= player
			continue
		if(is_centcom_level(player.z))
			living_players -= player // We don't autotator people in CentCom
			continue
		if(player.mind && (player.mind.special_role || player.mind.antag_datums?.len > 0))
			living_players -= player // We don't autotator people with roles already


/datum/dynamic_ruleset/midround/families/pre_execute()
	gangs_to_use = subtypesof(/datum/antagonist/gang)
	for(var/j = 0, j < gangs_to_generate, j++)
		if (!living_players.len)
			break
		var/datum/mind/gangbanger = pick_n_take(living_players)
		gangbangers += gangbanger
		gangbanger.restricted_roles = restricted_roles
		log_game("[key_name(gangbanger)] has been selected as a starting gangster!")
	for(var/j = 0, j < gangs_to_generate, j++)
		if(!living_players.len)
			break
		var/datum/mind/one_eight_seven_on_an_undercover_cop = pick_n_take(living_players)
		pigs += one_eight_seven_on_an_undercover_cop
		undercover_cops += one_eight_seven_on_an_undercover_cop
		one_eight_seven_on_an_undercover_cop.restricted_roles = restricted_roles
		log_game("[key_name(one_eight_seven_on_an_undercover_cop)] has been selected as a starting undercover cop!")
	endtime = world.time + time_to_end
	start_time = world.time
	return TRUE

/datum/dynamic_ruleset/midround/families/execute()
	var/replacement_gangsters = 0
	var/replacement_cops = 0
	for(var/datum/mind/gangbanger in gangbangers)
		if(!ishuman(gangbanger.current))
			gangbangers.Remove(gangbanger)
			log_game("DYNAMIC: [gangbanger] was not a human, and thus has lost their gangster role.")
			replacement_gangsters++
	if(replacement_gangsters)
		for(var/j = 0, j < replacement_gangsters, j++)
			if(!living_players.len)
				log_game("DYNAMIC: Unable to find more replacement gangsters. Not all of the gangs will spawn.")
				break
			var/datum/mind/gangbanger = pick_n_take(living_players)
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
			if(!living_players.len)
				log_game("DYNAMIC: Unable to find more replacement undercover cops. Not all of the gangs will spawn.")
				break
			var/datum/mind/undercover_cop = pick_n_take(living_players)
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

/datum/dynamic_ruleset/midround/families/rule_process()
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

/datum/dynamic_ruleset/midround/families/proc/announce_gang_locations()
	var/list/readable_gang_names = list()
	for(var/GG in gangs)
		var/datum/team/gang/G = GG
		readable_gang_names += "[G.name]"
	var/finalized_gang_names = english_list(readable_gang_names)
	priority_announce("Julio G coming to you live from Radio Los Spess! We've been hearing reports of gang activity on [station_name()], with the [finalized_gang_names] duking it out, looking for fresh territory and drugs to sling! Stay safe out there for the thirty minutes 'till the space cops get there, and keep it cool, yeah?\n\n The local jump gates are shut down for about thirty minutes due to some maintenance troubles, so if you wanna split from the area you're gonna have to wait an hour. \n Play music, not gunshots, I say. Peace out!", "Radio Los Spess", 'sound/voice/beepsky/radio.ogg')
	sent_announcement = TRUE

/datum/dynamic_ruleset/roundstart/families/proc/five_minute_warning()
	priority_announce("Julio G coming to you live from Radio Los Spess! The space cops are closing in on [station_name()] and will arrive in about 5 minutes! Better clear on out of there if you don't want to get hurt!", "Radio Los Spess", 'sound/voice/beepsky/radio.ogg')


/datum/dynamic_ruleset/midround/families/round_result()
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
/datum/dynamic_ruleset/midround/families/proc/check_wanted_level()
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
/datum/dynamic_ruleset/midround/families/proc/update_wanted_level(newlevel)
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

/datum/dynamic_ruleset/midround/families/proc/on_gain_wanted_level(newlevel)
	var/announcement_message
	switch(newlevel)
		if(2)
			announcement_message = "Small amount of police vehicles have been spotted en route towards [station_name()]. They will arrive at the 25 minute mark."
			endtime = start_time + 25 MINUTES
		if(3)
			announcement_message = "A large detachment police vehicles have been spotted en route towards [station_name()]. They will arrive at the 20 minute mark."
			endtime = start_time + 20 MINUTES
		if(4)
			announcement_message = "A detachment of top-trained agents has been spotted on their way to [station_name()]. They will arrive at the 15 minute mark."
			endtime = start_time + 15 MINUTES
		if(5)
			announcement_message = "The fleet enroute to [station_name()] now consists of national guard personnel. They will arrive at the 10 minute mark."
			endtime = start_time + 10 MINUTES
	priority_announce(announcement_message, "Station Spaceship Detection Systems")

/datum/dynamic_ruleset/midround/families/proc/on_lower_wanted_level(newlevel)
	var/announcement_message
	switch(newlevel)
		if(1)
			announcement_message = "There are now only a few police vehicle headed towards [station_name()]. They will arrive at the 30 minute mark."
			endtime = start_time + 30 MINUTES
		if(2)
			announcement_message = "There seem to be fewer police vehicles headed towards [station_name()]. They will arrive at the 25 minute mark."
			endtime = start_time + 25 MINUTES
		if(3)
			announcement_message = "There are no longer top-trained agents in the fleet headed towards [station_name()]. They will arrive at the 20 minute mark."
			endtime = start_time + 20 MINUTES
		if(4)
			announcement_message = "The convoy enroute to [station_name()] seems to no longer consist of national guard personnel. They will arrive at the 15 minute mark."
			endtime = start_time + 15 MINUTES
	priority_announce(announcement_message, "Station Spaceship Detection Systems")

/datum/dynamic_ruleset/midround/families/proc/send_in_the_fuzz()
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

/datum/dynamic_ruleset/midround/families/proc/end_hostile_sit()
	SSshuttle.clearHostileEnvironment(src)


/datum/dynamic_ruleset/midround/families/proc/check_tagged_turfs()
	for(var/T in GLOB.gang_tags)
		var/obj/effect/decal/cleanable/crayon/gang/tag = T
		if(tag.my_gang)
			tag.my_gang.adjust_points(50)
		CHECK_TICK

/datum/dynamic_ruleset/midround/families/proc/check_gang_clothes() // TODO: make this grab the sprite itself, average out what the primary color would be, then compare how close it is to the gang color so I don't have to manually fill shit out for 5 years for every gang type
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

/datum/dynamic_ruleset/midround/families/proc/check_rollin_with_crews()
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


//////////////////////////////////////////////
//                                          //
//         Malfunctioning AI                //
//                              		    //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/malf
	name = "Malfunctioning AI"
	antag_datum = /datum/antagonist/traitor
	antag_flag = ROLE_MALF
	enemy_roles = list("Security Officer", "Warden","Detective","Head of Security", "Captain", "Scientist", "Chemist", "Research Director", "Chief Engineer")
	exclusive_roles = list("AI")
	required_enemies = list(4,4,4,4,4,4,2,2,2,0)
	required_candidates = 1
	weight = 3
	cost = 35
	requirements = list(101,101,80,70,60,60,50,50,40,40)
	high_population_requirement = 35
	required_type = /mob/living/silicon/ai
	var/ion_announce = 33
	var/removeDontImproveChance = 10

/datum/dynamic_ruleset/midround/malf/trim_candidates()
	..()
	candidates = living_players
	for(var/mob/living/player in candidates)
		if(!isAI(player))
			candidates -= player
			continue
		if(is_centcom_level(player.z))
			candidates -= player
			continue
		if(player.mind && (player.mind.special_role || player.mind.antag_datums?.len > 0))
			candidates -= player

/datum/dynamic_ruleset/midround/malf/execute()
	if(!candidates || !candidates.len)
		return FALSE
	var/mob/living/silicon/ai/M = pick_n_take(candidates)
	assigned += M.mind
	var/datum/antagonist/traitor/AI = new
	M.mind.special_role = antag_flag
	M.mind.add_antag_datum(AI)
	if(prob(ion_announce))
		priority_announce("Ion storm detected near the station. Please check all AI-controlled equipment for errors.", "Anomaly Alert", 'sound/ai/ionstorm.ogg')
		if(prob(removeDontImproveChance))
			M.replace_random_law(generate_ion_law(), list(LAW_INHERENT, LAW_SUPPLIED, LAW_ION))
		else
			M.add_ion_law(generate_ion_law())
	return TRUE

//////////////////////////////////////////////
//                                          //
//              WIZARD (GHOST)              //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/wizard
	name = "Wizard"
	antag_datum = /datum/antagonist/wizard
	antag_flag = ROLE_WIZARD
	enemy_roles = list("Security Officer","Detective","Head of Security", "Captain")
	required_enemies = list(2,2,1,1,1,1,1,0,0,0)
	required_candidates = 1
	weight = 1
	cost = 20
	requirements = list(90,90,70,40,30,20,10,10,10,10)
	high_population_requirement = 50
	repeatable = TRUE

/datum/dynamic_ruleset/midround/from_ghosts/wizard/ready(forced = FALSE)
	if (required_candidates > (dead_players.len + list_observers.len))
		return FALSE
	if(GLOB.wizardstart.len == 0)
		log_admin("Cannot accept Wizard ruleset. Couldn't find any wizard spawn points.")
		message_admins("Cannot accept Wizard ruleset. Couldn't find any wizard spawn points.")
		return FALSE
	return ..()

/datum/dynamic_ruleset/midround/from_ghosts/wizard/finish_setup(mob/new_character, index)
	..()
	new_character.forceMove(pick(GLOB.wizardstart))

//////////////////////////////////////////////
//                                          //
//          NUCLEAR OPERATIVES (MIDROUND)   //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/nuclear
	name = "Nuclear Assault"
	antag_flag = ROLE_OPERATIVE
	antag_datum = /datum/antagonist/nukeop
	enemy_roles = list("AI", "Cyborg", "Security Officer", "Warden","Detective","Head of Security", "Captain")
	required_enemies = list(3,3,3,3,3,2,1,1,0,0)
	required_candidates = 5
	weight = 5
	cost = 35
	requirements = list(90,90,90,80,60,40,30,20,10,10)
	high_population_requirement = 10
	var/list/operative_cap = list(2,2,3,3,4,5,5,5,5,5)
	var/datum/team/nuclear/nuke_team
	flags = HIGHLANDER_RULESET

/datum/dynamic_ruleset/midround/from_ghosts/nuclear/acceptable(population=0, threat=0)
	if (locate(/datum/dynamic_ruleset/roundstart/nuclear) in mode.executed_rules)
		return FALSE // Unavailable if nuke ops were already sent at roundstart
	indice_pop = min(operative_cap.len, round(living_players.len/5)+1)
	required_candidates = operative_cap[indice_pop]
	return ..()

/datum/dynamic_ruleset/midround/from_ghosts/nuclear/ready(forced = FALSE)
	if (required_candidates > (dead_players.len + list_observers.len))
		return FALSE
	return ..()

/datum/dynamic_ruleset/midround/from_ghosts/nuclear/finish_setup(mob/new_character, index)
	new_character.mind.special_role = "Nuclear Operative"
	new_character.mind.assigned_role = "Nuclear Operative"
	if (index == 1) // Our first guy is the leader
		var/datum/antagonist/nukeop/leader/new_role = new
		nuke_team = new_role.nuke_team
		new_character.mind.add_antag_datum(new_role)
	else
		return ..()

//////////////////////////////////////////////
//                                          //
//              BLOB (GHOST)                //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/blob
	name = "Blob"
	antag_datum = /datum/antagonist/blob
	antag_flag = ROLE_BLOB
	enemy_roles = list("Security Officer", "Detective", "Head of Security", "Captain")
	required_enemies = list(2,2,1,1,1,1,1,0,0,0)
	required_candidates = 1
	weight = 4
	cost = 10
	requirements = list(101,101,101,80,60,50,30,20,10,10)
	high_population_requirement = 50
	repeatable = TRUE

/datum/dynamic_ruleset/midround/from_ghosts/blob/generate_ruleset_body(mob/applicant)
	var/body = applicant.become_overmind()
	return body

//////////////////////////////////////////////
//                                          //
//           XENOMORPH (GHOST)              //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/xenomorph
	name = "Alien Infestation"
	antag_datum = /datum/antagonist/xeno
	antag_flag = ROLE_ALIEN
	enemy_roles = list("Security Officer", "Detective", "Head of Security", "Captain")
	required_enemies = list(2,2,1,1,1,1,1,0,0,0)
	required_candidates = 1
	weight = 3
	cost = 10
	requirements = list(101,101,101,70,50,40,20,15,10,10)
	high_population_requirement = 50
	repeatable = TRUE
	var/list/vents = list()

/datum/dynamic_ruleset/midround/from_ghosts/xenomorph/execute()
	// 50% chance of being incremented by one
	required_candidates += prob(50)
	for(var/obj/machinery/atmospherics/components/unary/vent_pump/temp_vent in GLOB.machines)
		if(QDELETED(temp_vent))
			continue
		if(is_station_level(temp_vent.loc.z) && !temp_vent.welded)
			var/datum/pipeline/temp_vent_parent = temp_vent.parents[1]
			if(!temp_vent_parent)
				continue // No parent vent
			// Stops Aliens getting stuck in small networks.
			// See: Security, Virology
			if(temp_vent_parent.other_atmosmch.len > 20)
				vents += temp_vent
	if(!vents.len)
		return FALSE
	. = ..()

/datum/dynamic_ruleset/midround/from_ghosts/xenomorph/generate_ruleset_body(mob/applicant)
	var/obj/vent = pick_n_take(vents)
	var/mob/living/carbon/alien/larva/new_xeno = new(vent.loc)
	new_xeno.key = applicant.key
	message_admins("[ADMIN_LOOKUPFLW(new_xeno)] has been made into an alien by the midround ruleset.")
	log_game("DYNAMIC: [key_name(new_xeno)] was spawned as an alien by the midround ruleset.")
	return new_xeno

//////////////////////////////////////////////
//                                          //
//           NIGHTMARE (GHOST)              //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/nightmare
	name = "Nightmare"
	antag_datum = /datum/antagonist/nightmare
	antag_flag = "Nightmare"
	antag_flag_override = ROLE_ALIEN
	enemy_roles = list("Security Officer", "Detective", "Head of Security", "Captain")
	required_enemies = list(2,2,1,1,1,1,1,0,0,0)
	required_candidates = 1
	weight = 3
	cost = 10
	requirements = list(101,101,101,70,50,40,20,15,10,10)
	high_population_requirement = 50
	repeatable = TRUE
	var/list/spawn_locs = list()

/datum/dynamic_ruleset/midround/from_ghosts/nightmare/execute()
	for(var/X in GLOB.xeno_spawn)
		var/turf/T = X
		var/light_amount = T.get_lumcount()
		if(light_amount < SHADOW_SPECIES_LIGHT_THRESHOLD)
			spawn_locs += T
	if(!spawn_locs.len)
		return FALSE
	. = ..()

/datum/dynamic_ruleset/midround/from_ghosts/nightmare/generate_ruleset_body(mob/applicant)
	var/datum/mind/player_mind = new /datum/mind(applicant.key)
	player_mind.active = TRUE

	var/mob/living/carbon/human/S = new (pick(spawn_locs))
	player_mind.transfer_to(S)
	player_mind.assigned_role = "Nightmare"
	player_mind.special_role = "Nightmare"
	player_mind.add_antag_datum(/datum/antagonist/nightmare)
	S.set_species(/datum/species/shadow/nightmare)

	playsound(S, 'sound/magic/ethereal_exit.ogg', 50, TRUE, -1)
	message_admins("[ADMIN_LOOKUPFLW(S)] has been made into a Nightmare by the midround ruleset.")
	log_game("DYNAMIC: [key_name(S)] was spawned as a Nightmare by the midround ruleset.")
	return S

//////////////////////////////////////////////
//                                          //
//           SPACE DRAGON (GHOST)           //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/space_dragon
	name = "Space Dragon"
	antag_datum = /datum/antagonist/space_dragon
	antag_flag = "Space Dragon"
	antag_flag_override = ROLE_SPACE_DRAGON
	enemy_roles = list("Security Officer", "Detective", "Head of Security", "Captain")
	required_enemies = list(2,2,1,1,1,1,1,0,0,0)
	required_candidates = 1
	weight = 4
	cost = 10
	requirements = list(101,101,101,80,60,50,30,20,10,10)
	high_population_requirement = 50
	repeatable = TRUE
	var/list/spawn_locs = list()

/datum/dynamic_ruleset/midround/from_ghosts/space_dragon/execute()
	for(var/obj/effect/landmark/carpspawn/C in GLOB.landmarks_list)
		spawn_locs += (C.loc)
	if(!spawn_locs.len)
		message_admins("No valid spawn locations found, aborting...")
		return MAP_ERROR
	. = ..()

/datum/dynamic_ruleset/midround/from_ghosts/space_dragon/generate_ruleset_body(mob/applicant)
	var/datum/mind/player_mind = new /datum/mind(applicant.key)
	player_mind.active = TRUE

	var/mob/living/simple_animal/hostile/space_dragon/S = new (pick(spawn_locs))
	player_mind.transfer_to(S)
	player_mind.assigned_role = "Space Dragon"
	player_mind.special_role = "Space Dragon"
	player_mind.add_antag_datum(/datum/antagonist/space_dragon)

	playsound(S, 'sound/magic/ethereal_exit.ogg', 50, TRUE, -1)
	message_admins("[ADMIN_LOOKUPFLW(S)] has been made into a Space Dragon by the midround ruleset.")
	log_game("DYNAMIC: [key_name(S)] was spawned as a Space Dragon by the midround ruleset.")
	priority_announce("A large organic energy flux has been recorded near of [station_name()], please stand-by.", "Lifesign Alert")
	return S

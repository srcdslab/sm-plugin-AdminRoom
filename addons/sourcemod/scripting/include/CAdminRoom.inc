#if defined _class_cadminroom_
  #endinput
#endif
#define _class_cadminroom_

#include <basic>

methodmap CAdminRoomLocation < Basic
{
	public CAdminRoomLocation()
	{
		Basic myclass = new Basic();

		myclass.SetString("sName", "");
		myclass.SetArray("fOrigin", {0, 0, 0}, 3);

		return view_as<CAdminRoomLocation>(myclass);
	}

	public bool GetName(char[] buffer, int length)
	{
		return this.GetString("sName", buffer, length);
	}

	public void SetName(const char[] buffer)
	{
		this.SetString("sName", buffer);
	}

	public bool GetOrigin(float vector[3])
	{
		return this.GetArray("fOrigin", vector, sizeof(vector));
	}

	public void SetOrigin(const float vector[3])
	{
		this.SetArray("fOrigin", vector, sizeof(vector));
	}
}

methodmap CTrigger < Basic
{
	public CTrigger()
	{
		Basic myclass = new Basic();

		myclass.SetString("sKey", "");
		myclass.SetString("sValue", "");

		return view_as<CTrigger>(myclass);
	}

	public bool GetKey(char[] buffer, int length)
	{
		return this.GetString("sKey", buffer, length);
	}

	public void SetKey(const char[] buffer)
	{
		this.SetString("sKey", buffer);
	}

	public bool GetValue(char[] buffer, int length)
	{
		return this.GetString("sValue", buffer, length);
	}

	public void SetValue(const char[] buffer)
	{
		this.SetString("sValue", buffer);
	}
}

methodmap CAction < Basic
{
	public CAction()
	{
		Basic myclass = new Basic();

		myclass.SetString("sKey", "");
		myclass.SetString("sIdentifier", "");
		myclass.SetString("sEvent", "");

		return view_as<CAction>(myclass);
	}

	public bool GetKey(char[] buffer, int length)
	{
		return this.GetString("sKey", buffer, length);
	}

	public void SetKey(const char[] buffer)
	{
		this.SetString("sKey", buffer);
	}

	public bool GetIdentifier(char[] buffer, int length)
	{
		return this.GetString("sIdentifier", buffer, length);
	}

	public void SetIdentifier(const char[] buffer)
	{
		this.SetString("sIdentifier", buffer);
	}

	public bool GetEvent(char[] buffer, int length)
	{
		return this.GetString("sEvent", buffer, length);
	}

	public void SetEvent(const char[] buffer)
	{
		this.SetString("sEvent", buffer);
	}
}

methodmap CStage < Basic
{
	public CStage()
	{
		Basic myclass = new Basic();

		myclass.SetString("sName", "");
		myclass.SetValue("cTriggers", new ArrayList());
		myclass.SetValue("cActions", new ArrayList());
		myclass.SetBool("bVotable", true);
		myclass.SetInt("iRtdPercent", 0);

		return view_as<CStage>(myclass);
	}

	public bool GetName(char[] buffer, int length)
	{
		return this.GetString("sName", buffer, length);
	}

	public void SetName(const char[] buffer)
	{
		this.SetString("sName", buffer);
	}

	public bool GetTriggers(ArrayList &cTriggers)
	{
		return this.GetValue("cTriggers", cTriggers);
	}

	public bool AddTrigger(const CTrigger cTrigger)
	{
		ArrayList cTriggers;
		if (this.GetTriggers(cTriggers))
		{
			cTriggers.Push(cTrigger);
			this.SetValue("cTriggers", cTriggers);
			return true;
		}

		return false;
	}

	public bool GetActions(ArrayList &cActions)
	{
		return this.GetValue("cActions", cActions);
	}

	public void AddAction(const CAction cAction)
	{
		ArrayList cActions;
		if (this.GetActions(cActions))
		{
			cActions.Push(cAction);
			this.SetValue("cActions", cActions);
		}
	}

	// Whether this stage can be picked by the stage vote. Defaults to true; set to false in the
	// map config for stages that are one-off effects rather than real difficulty choices.
	property bool bVotable
	{
		public get()
		{
			return this.GetBool("bVotable");
		}
		public set(bool value)
		{
			this.SetBool("bVotable", value);
		}
	}

	// Percent chance (1-100) this stage is auto-selected without a vote the first time the vote
	// fires this map, e.g. a rare/bonus stage. 0 (default) disables this "roll the dice" behavior.
	property int iRtdPercent
	{
		public get()
		{
			return this.GetInt("iRtdPercent");
		}
		public set(int value)
		{
			this.SetInt("iRtdPercent", value);
		}
	}
}

methodmap CVoteConfig < Basic
{
	public CVoteConfig()
	{
		Basic myclass = new Basic();

		myclass.SetBool("bEnabled", false);
		myclass.SetInt("iPercent", 60);
		myclass.SetFloat("fDelay", 3.0);
		myclass.SetInt("iCountdown", 3);
		myclass.SetInt("iCooldownMax", 2);
		myclass.SetValue("cOnStartActions", new ArrayList());

		return view_as<CVoteConfig>(myclass);
	}

	property bool bEnabled
	{
		public get()
		{
			return this.GetBool("bEnabled");
		}
		public set(bool value)
		{
			this.SetBool("bEnabled", value);
		}
	}

	// Percent of votes the winning stage needs to avoid a revote.
	property int iPercent
	{
		public get()
		{
			return this.GetInt("iPercent");
		}
		public set(int value)
		{
			this.SetInt("iPercent", value);
		}
	}

	// Delay, in seconds, before the round is terminated when an admin starts a vote manually.
	property float fDelay
	{
		public get()
		{
			return this.GetFloat("fDelay");
		}
		public set(float value)
		{
			this.SetFloat("fDelay", value);
		}
	}

	// Countdown, in seconds, shown to players before the vote menu opens.
	property int iCountdown
	{
		public get()
		{
			return this.GetInt("iCountdown");
		}
		public set(int value)
		{
			this.SetInt("iCountdown", value);
		}
	}

	// Number of most-recently-played stages kept disabled in the vote menu before the cooldown resets.
	property int iCooldownMax
	{
		public get()
		{
			return this.GetInt("iCooldownMax");
		}
		public set(int value)
		{
			this.SetInt("iCooldownMax", value);
		}
	}

	// Actions (same "identifier:event" format as stage actions) fired once when a vote starts,
	// e.g. killing ambient music entities or playing a victory sound/game_text.
	public bool GetOnStartActions(ArrayList &cActions)
	{
		return this.GetValue("cOnStartActions", cActions);
	}

	public void AddOnStartAction(const CAction cAction)
	{
		ArrayList cActions;
		if (this.GetOnStartActions(cActions))
		{
			cActions.Push(cAction);
			this.SetValue("cOnStartActions", cActions);
		}
	}
}

methodmap CAdminRoom < Basic
{
	public CAdminRoom()
	{
		Basic myclass = new Basic();

		myclass.SetBool("bEnabled", false);
		myclass.SetValue("cAdminRoomLocations", new ArrayList());
		myclass.SetValue("cStages", new ArrayList());
		myclass.SetValue("cVoteConfig", new CVoteConfig());

		return view_as<CAdminRoom>(myclass);
	}

	public bool GetAdminRoomLocations(ArrayList &cAdminRoomLocations)
	{
		return this.GetValue("cAdminRoomLocations", cAdminRoomLocations);
	}

	public void AddAdminRoomLocation(const CAdminRoomLocation cAdminRoomLocation)
	{
		ArrayList cAdminRoomLocations;
		if (this.GetAdminRoomLocations(cAdminRoomLocations))
		{
			cAdminRoomLocations.Push(cAdminRoomLocation);
			this.SetValue("cAdminRoomLocations", cAdminRoomLocations);
		}
	}

	public bool GetStages(ArrayList &cStages)
	{
		return this.GetValue("cStages", cStages);
	}

	public void AddStage(const CStage cStage)
	{
		ArrayList cStages;
		if (this.GetStages(cStages))
		{
			cStages.Push(cStage);
			this.SetValue("cStages", cStages);
		}
	}

	public bool GetVoteConfig(CVoteConfig &cVoteConfig)
	{
		return this.GetValue("cVoteConfig", cVoteConfig);
	}

	property bool bEnabled
	{
		public get()
		{
			return this.GetBool("bEnabled");
		}
		public set(bool value)
		{
			this.SetBool("bEnabled", value);
		}
	}
}
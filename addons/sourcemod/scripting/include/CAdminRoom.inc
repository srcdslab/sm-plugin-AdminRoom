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
		}
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
}

methodmap CAdminRoom < Basic
{
	public CAdminRoom()
	{
		Basic myclass = new Basic();

		myclass.SetBool("bEnabled", false);
		myclass.SetValue("cAdminRoomLocations", new ArrayList());
		myclass.SetValue("cStages", new ArrayList());

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
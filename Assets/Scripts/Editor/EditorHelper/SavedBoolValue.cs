using UnityEditor;
public class SavedBoolValue
{
    bool m_Value;
    string m_Name;
    bool m_Loaded;

    public SavedBoolValue(string name, bool value)
    {
        m_Name = name;
        m_Loaded = false;
        m_Value = value;
    }

    void Load()
    {
        if (m_Loaded)
            return;

        m_Loaded = true;
        m_Value = EditorPrefs.GetBool(m_Name, m_Value);
    }

    public bool value
    {
        get
        {
            Load();
            return m_Value;
        }
        set
        {
            Load();
            if (m_Value == value)
                return;
            m_Value = value;
            EditorPrefs.SetBool(m_Name, value);
        }
    }
}
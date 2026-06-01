local addonName, SQ = ...
SQ = SQ or {}

function SQ.DebugPrint(message)
    if SoloQSettings and SoloQSettings.debug and print then
        print("|cff33ff99SoloQ|r " .. tostring(message))
    end
end

function SQ.SetStatus(message, quiet)
    SQ.lastStatus = tostring(message or "")
    if SQ.UI and SQ.UI.UpdateStatus then
        SQ.UI.UpdateStatus()
    end
    -- quiet updates the side panel only; they skip the chat debug print so that
    -- high-frequency messages (e.g. per-applicant evaluation) do not spam chat.
    if not quiet then
        SQ.DebugPrint(SQ.lastStatus)
    end
end

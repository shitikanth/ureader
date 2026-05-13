#pragma once
#include <string>
#include <unordered_map>

class StateStore {
public:
    static StateStore& shared();

    // Returns 0 if no saved position for this uid.
    int positionForUID(const std::string& uid) const;

    // Saves spineIndex for this uid and persists to disk immediately.
    void setPosition(int spineIndex, const std::string& uid);

private:
    StateStore();
    void load();
    void save() const;

    std::string path_;
    std::unordered_map<std::string, int> positions_;
};

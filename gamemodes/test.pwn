#include <a_samp>

main() {
	print("Loading...");
}

public OnGameModeInit() {
	SetGameModeText("Snake gamemode");
	AddPlayerClass(265, 1958.3783, 1343.1572, 15.3746, 270.1425, 0, 0, 0, 0, 0, 0);
	
	return 1;
}

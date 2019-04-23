#include <a_samp>
#include <streamer> // https://github.com/samp-incognito/samp-streamer-plugin

#undef MAX_PLAYERS
#define MAX_PLAYERS			5 // чем меньше тем лучше

#define DEFAULT_X			1328.4181 // x
#define DEFAULT_Y			2132.8904 // y
#define DEFAULT_Z			11.1 // высота
#define DEFAULT_SIZE		3 // количество начальных точек (обязательно больше 0)
#define DEFAULT_VWORLD		1500 // виртуальный мир
#define DEFAULT_DIALOGID	1000 // ид диалога
#define DEFAULT_TIME		300 // стандартное время таймера

#define CAMERA_HEIGHT		25.0 // высота камеры
#define CAMERA_INCLINE		0.001 // наклон камеры (обязательно больше 0)

#define MAX_ZONE_WIDTH		22 // шырина
#define MAX_ZONE_HEIGHT		18 // высота

#define MAX_BARRIER_SIZE	(MAX_ZONE_WIDTH * MAX_ZONE_HEIGHT) * 5 / 100 // количество барьеров (не трогать)
#define MAX_ZONE_SIZE		(MAX_ZONE_WIDTH * 2) + (MAX_ZONE_HEIGHT * 2) - 4 // количество объектов игровой зоны (не трогать)
#define MAX_SNAKE_SIZE		(MAX_ZONE_WIDTH - 2) * (MAX_ZONE_HEIGHT - 2) // количество елементов змейки (не трогать)

// Игрок
enum player_info {
	bool:	player_start,
			player_timer,
	bool:	player_pause,
			player_key1,
			player_key2,
	bool:	player_barrier,
	bool:	player_collision,
	bool:	player_fperson,
			player_afk
}
new PlayerInfo[MAX_PLAYERS][player_info];

// Игровая зона
new ZoneObject[MAX_PLAYERS][MAX_ZONE_SIZE];
new ZoneText[MAX_PLAYERS];

// Змейка
enum snake_info {
	Float:	snake_x,
	Float:	snake_y,
			snake_object,
	Float:	snake_oldx,
	Float:	snake_oldy,
	bool:	snake_collision
}
new SnakeInfo[MAX_PLAYERS][MAX_SNAKE_SIZE][snake_info];
new SnakeSize[MAX_PLAYERS];

// Предмет
enum item_info {
	Float:	item_x,
	Float:	item_y,
			item_object
}
new ItemInfo[MAX_PLAYERS][item_info];

// Берьеры
enum barrier_info {
	Float:	barrier_x,
	Float:	barrier_y,
			barrier_object
}
new BarrierInfo[MAX_PLAYERS][MAX_BARRIER_SIZE][barrier_info];

public OnPlayerUpdate(playerid) {
	if(PlayerInfo[playerid][player_start] && PlayerInfo[playerid][player_timer]) {
		// Получение нажатий
		new keys, updown, leftright;
		GetPlayerKeys(playerid, keys, updown, leftright);

		// Афк
		PlayerInfo[playerid][player_afk] = GetTickCount();

		// Пауза
		if(keys == 32) {
			if(PlayerInfo[playerid][player_pause]) {
				PlayerInfo[playerid][player_pause] = false;
			} else {
				PlayerInfo[playerid][player_pause] = true;
			}
			PlayerPlaySound(playerid, 17001, 0.0, 0.0, 0.0);
		}

		// Перемещение
		if(!PlayerInfo[playerid][player_pause]) {
			if(PlayerInfo[playerid][player_fperson]) {
				new Float:angle;
				Streamer_GetFloatData(STREAMER_TYPE_OBJECT, SnakeInfo[playerid][0][snake_object], E_STREAMER_R_Z, angle);
				if(angle == -90.0) {
					if(leftright == KEY_LEFT) {
						PlayerInfo[playerid][player_key1] = 1;
					} else if(leftright == KEY_RIGHT) {
						PlayerInfo[playerid][player_key1] = 0;
					}
				} else if(angle == 90.0) {
					if(leftright == KEY_LEFT) {
						PlayerInfo[playerid][player_key1] = 0;
					} else if(leftright == KEY_RIGHT) {
						PlayerInfo[playerid][player_key1] = 1;
					}
				} else if(angle == 0.0) {
					if(leftright == KEY_LEFT) {
						PlayerInfo[playerid][player_key1] = 3;
					} else if(leftright == KEY_RIGHT) {
						PlayerInfo[playerid][player_key1] = 2;
					}
				} else if(angle == 180.0) {
					if(leftright == KEY_LEFT) {
						PlayerInfo[playerid][player_key1] = 2;
					} else if(leftright == KEY_RIGHT) {
						PlayerInfo[playerid][player_key1] = 3;
					}
				}
			} else {
				if(updown == KEY_UP && PlayerInfo[playerid][player_key2] != 1) { // UP
					PlayerInfo[playerid][player_key1] = 0;
				} else if(updown == KEY_DOWN && PlayerInfo[playerid][player_key2] != 0) { // DOWN
					PlayerInfo[playerid][player_key1] = 1;
				} else if(leftright == KEY_LEFT && PlayerInfo[playerid][player_key2] != 3) { // LEFT
					PlayerInfo[playerid][player_key1] = 2;
				} else if(leftright == KEY_RIGHT && PlayerInfo[playerid][player_key2] != 2) { // RIGHT
					PlayerInfo[playerid][player_key1] = 3;
				}
			}
		}
	}
	return 1;
}

public OnPlayerConnect(playerid) {
	SendClientMessage(playerid, -1, "Чтобы играть в змейку, введите {ff0000}/start");
	return 1;
}

public OnPlayerSpawn(playerid) {
	StopGame(playerid, false);
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason) {
	StopGame(playerid, false);
	return 1;
}

public OnPlayerDisconnect(playerid, reason) {
	StopGame(playerid, false);
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[]) {
	if(strcmp("/start", cmdtext, true, 6) == 0) {
		if(PlayerInfo[playerid][player_start]) {
			PlayerInfo[playerid][player_pause] = true;
			ShowPlayerDialog(playerid, DEFAULT_DIALOGID + 1, DIALOG_STYLE_LIST, "Snake", "- Перезапустить\n- Покуинуть игру", "Выбор", "Закрыть");
		} else {
			ShowPlayerDialog(playerid, DEFAULT_DIALOGID + 0, DIALOG_STYLE_TABLIST_HEADERS, "Snake", "Выберите режим игры:\n- Обычная игра\n- Игра с барьерами\n- Игра без коллизии\n- От первого лица", "Играть", "Закрыть");
		}
		return 1;
	}
	return 0;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]) {
	switch(dialogid) {
		// Начало игры
		case DEFAULT_DIALOGID + 0: {
			if(response) {
				StartGame(playerid, listitem);
				GameTextForPlayer(playerid, "~k~~PED_JUMPING~", 3000, 4);
			}
			return 1;
		}
		// Выход & Рестарт
		case DEFAULT_DIALOGID + 1: {
			if(response) {
				if(listitem == 0) {
					RestartGame(playerid);
					GameTextForPlayer(playerid, "~k~~PED_JUMPING~", 3000, 4);
				} else {
					StopGame(playerid);
				}
			}
			return 1;
		}
		// Победа или смерть
		case DEFAULT_DIALOGID + 2: {
			if(response) {
				RestartGame(playerid);
				GameTextForPlayer(playerid, "~k~~PED_JUMPING~", 3000, 4);
			} else {
				StopGame(playerid);
			}
			return 1;
		}
	}
	return 1;
}

stock StartGame(playerid, mode = 1) {
	if(!PlayerInfo[playerid][player_start]) {
		// Режим игры
		switch(mode) {
			case 0: { // Обычная игра
				PlayerInfo[playerid][player_barrier] = false;
				PlayerInfo[playerid][player_collision] = false;
				PlayerInfo[playerid][player_fperson] = false;
			}
			case 1: { // Игра с барьерами
				PlayerInfo[playerid][player_barrier] = true;
				PlayerInfo[playerid][player_collision] = false;
				PlayerInfo[playerid][player_fperson] = false;
			}
			case 2: { // Игра без коллизии
				PlayerInfo[playerid][player_barrier] = false;
				PlayerInfo[playerid][player_collision] = true;
				PlayerInfo[playerid][player_fperson] = false;
			}
			case 3: { // От первого лица
				PlayerInfo[playerid][player_barrier] = false;
				PlayerInfo[playerid][player_collision] = false;
				PlayerInfo[playerid][player_fperson] = true;
			}
		}

		// Создаем карту
		for(new a, Float:x = DEFAULT_X, Float:y = DEFAULT_Y, index; a < MAX_ZONE_HEIGHT; a++) {
			for(new b; b < MAX_ZONE_WIDTH; b++) {
				if(a == 0 || a == (MAX_ZONE_HEIGHT - 1) || b == 0 || b == (MAX_ZONE_WIDTH - 1)) {
					ZoneObject[playerid][index] = CreateDynamicObject(19789, x, y, DEFAULT_Z, 0.0, 0.0, 0.0, DEFAULT_VWORLD, 0, playerid);
					SetDynamicObjectMaterial(ZoneObject[playerid][index], 0, 10931, "traingen_sfse", "metpat64", 0xFFFFFFFF);
					index++;
				}
				x += 1.0;
			}
			x = DEFAULT_X;
			y += 1.0;
		}

		// Отображение счета
		ZoneText[playerid] = CreateDynamicObject((PlayerInfo[playerid][player_fperson] ? 19476 : 19483), DEFAULT_X + MAX_ZONE_WIDTH - 1.80, DEFAULT_Y + 0.1, DEFAULT_Z + 1.01, 180.0, 90.0, 90.0, DEFAULT_VWORLD, 0, playerid);

		// Создаем змея & предмета
		CreateSnake(playerid);
		if(PlayerInfo[playerid][player_barrier]) {
			CreateBarrier(playerid);
		}
		CreateItem(playerid);

		// Обновляем камеру
		new Float:x = DEFAULT_X + MAX_ZONE_WIDTH / 2.0 - 0.5;
		new Float:y = DEFAULT_Y + MAX_ZONE_HEIGHT / 2.0 - 0.5;
		TogglePlayerControllable(playerid, 0);
		SetPlayerVirtualWorld(playerid, DEFAULT_VWORLD);
		SetPlayerInterior(playerid, 0);
		SetPlayerPos(playerid, x, y, DEFAULT_Z + CAMERA_HEIGHT + 10.0);
		if(PlayerInfo[playerid][player_fperson]) {
			UpdatePlayerCamera(playerid);
		} else {
			SetPlayerCameraPos(playerid, x, y - CAMERA_INCLINE, DEFAULT_Z + CAMERA_HEIGHT);
			SetPlayerCameraLookAt(playerid, x, y, DEFAULT_Z);
		}

		// Обновляем все объекты
		Streamer_Update(playerid, STREAMER_TYPE_OBJECT);

		// Создаем таймер
		PlayerInfo[playerid][player_pause] = true;
		PlayerInfo[playerid][player_start] = true;
		PlayerInfo[playerid][player_timer] = SetTimerEx("OnPlayerSnakeUpdate", DEFAULT_TIME, true, "d", playerid);
	}
}

stock StopGame(playerid, respawn = true) {
	if(PlayerInfo[playerid][player_start]) {
		// Телепорт игрока обратно
		if(respawn && IsPlayerConnected(playerid)) {
			SpawnPlayer(playerid);
			SetCameraBehindPlayer(playerid);
		}

		// Очистка переменных игрока
		KillTimer(PlayerInfo[playerid][player_timer]);
		PlayerInfo[playerid][player_timer] = 0;
		PlayerInfo[playerid][player_pause] = false;
		PlayerInfo[playerid][player_start] = false;
		PlayerInfo[playerid][player_key1] = 0;
		PlayerInfo[playerid][player_key2] = 0;
		PlayerInfo[playerid][player_barrier] = false;
		PlayerInfo[playerid][player_collision] = false;
		PlayerInfo[playerid][player_fperson] = false;

		// Удаляем игровую зону
		for(new i; i < MAX_ZONE_SIZE; i++) {
			if(IsValidDynamicObject(ZoneObject[playerid][i])) {
				DestroyDynamicObject(ZoneObject[playerid][i]);
			}
			ZoneObject[playerid][i] = 0;
		}

		// Удаление счета
		if(IsValidDynamicObject(ZoneText[playerid])) {
			DestroyDynamicObject(ZoneText[playerid]);
		}
		ZoneText[playerid] = 0;

		// Удаляем змейку
		SnakeSize[playerid] = 0;
		for(new i; i < MAX_SNAKE_SIZE; i++) {
			if(IsValidDynamicObject(SnakeInfo[playerid][i][snake_object])) {
				DestroyDynamicObject(SnakeInfo[playerid][i][snake_object]);
			}
			SnakeInfo[playerid][i][snake_object] = 0;
			SnakeInfo[playerid][i][snake_x] = 0.0;
			SnakeInfo[playerid][i][snake_y] = 0.0;
			SnakeInfo[playerid][i][snake_oldx] = 0.0;
			SnakeInfo[playerid][i][snake_oldy] = 0.0;
			SnakeInfo[playerid][i][snake_collision] = false;
		}

		// Удаляем предмет
		if(IsValidDynamicObject(ItemInfo[playerid][item_object])) {
			DestroyDynamicObject(ItemInfo[playerid][item_object]);
		}
		ItemInfo[playerid][item_object] = 0;
		ItemInfo[playerid][item_x] = 0.0;
		ItemInfo[playerid][item_y] = 0.0;

		// Удаляем барьеры
		for(new i; i < MAX_BARRIER_SIZE; i++) {
			if(IsValidDynamicObject(BarrierInfo[playerid][i][barrier_object])) {
				DestroyDynamicObject(BarrierInfo[playerid][i][barrier_object]);
			}
			BarrierInfo[playerid][i][barrier_object] = 0;
		}
	}
}

stock RestartGame(playerid) {
	if(PlayerInfo[playerid][player_start]) {
		// Пересоздаем
		CreateSnake(playerid);
		if(PlayerInfo[playerid][player_barrier]) {
			CreateBarrier(playerid);
		}
		CreateItem(playerid);

		// Обновление камеры
		if(PlayerInfo[playerid][player_fperson]) {
			UpdatePlayerCamera(playerid);
		}

		// Обновляем объекты
		Streamer_Update(playerid, STREAMER_TYPE_OBJECT);

		// Переменные
		PlayerInfo[playerid][player_pause] = true;

		// Таймер
		KillTimer(PlayerInfo[playerid][player_timer]);
		PlayerInfo[playerid][player_timer] = SetTimerEx("OnPlayerSnakeUpdate", DEFAULT_TIME, true, "d", playerid);
	}
}

stock CreateSnake(playerid) {
	// Переменные
	PlayerInfo[playerid][player_key1] = 3;
	PlayerInfo[playerid][player_key2] = 3;
	SnakeSize[playerid] = DEFAULT_SIZE;

	// Создание
	new Float:y = DEFAULT_Y + 2.0 + random(MAX_ZONE_HEIGHT - 4); // Делаем рандомную высоту
	for(new i; i < MAX_SNAKE_SIZE; i++) {
		// Удаление объектов
		if(IsValidDynamicObject(SnakeInfo[playerid][i][snake_object])) {
			DestroyDynamicObject(SnakeInfo[playerid][i][snake_object]);
		}

		// Создание новой змейки
		if(i < SnakeSize[playerid]) {
			// Позиция
			SnakeInfo[playerid][i][snake_x] = SnakeInfo[playerid][i][snake_oldx] = DEFAULT_X + DEFAULT_SIZE - i + 1.0;
			SnakeInfo[playerid][i][snake_y] = SnakeInfo[playerid][i][snake_oldy] = y;

			// Объект
			SnakeInfo[playerid][i][snake_object] = CreateDynamicObject(19789, SnakeInfo[playerid][i][snake_x], SnakeInfo[playerid][i][snake_y], DEFAULT_Z, 0.0, 0.0, 90.0, DEFAULT_VWORLD, 0, playerid);
			if(i == 0) { // Голова
				SetDynamicObjectMaterial(SnakeInfo[playerid][i][snake_object], 0, 17079, "cuntwland", "ws_freeway4", 0xFFFFFFFF);
			} else {
				SetDynamicObjectMaterial(SnakeInfo[playerid][i][snake_object], 0, 8538, "vgsrailroad", "concreteyellow256 copy", 0xFFFFFFFF);
			}
		} else {
			SnakeInfo[playerid][i][snake_object] = 0;
			SnakeInfo[playerid][i][snake_x] = SnakeInfo[playerid][i][snake_oldx] = 0.0;
			SnakeInfo[playerid][i][snake_y] = SnakeInfo[playerid][i][snake_oldy] = 0.0;
		}
		SnakeInfo[playerid][i][snake_collision] = false;
	}
}

stock CreateItem(playerid) {
	// Устанавливаем позицию
	create: {
		// Позиция
		ItemInfo[playerid][item_x] = DEFAULT_X + 1.0 + random(MAX_ZONE_WIDTH - 2);
		ItemInfo[playerid][item_y] = DEFAULT_Y + 1.0 + random(MAX_ZONE_HEIGHT - 2);

		// Змейка
		for(new i = SnakeSize[playerid] - 1; i >= 0; i--) {
			if(ItemInfo[playerid][item_x] == SnakeInfo[playerid][i][snake_x]
			&& ItemInfo[playerid][item_y] == SnakeInfo[playerid][i][snake_y]) {
				goto create;
			}
		}

		// Барьеры
		if(PlayerInfo[playerid][player_barrier]) {
			for(new i; i < MAX_BARRIER_SIZE; i++) {
				if(ItemInfo[playerid][item_x] == BarrierInfo[playerid][i][barrier_x]
				&& ItemInfo[playerid][item_y] == BarrierInfo[playerid][i][barrier_y]) {
					goto create;
				}
			}
		}
	}

	// Пересоздаем
	if(IsValidDynamicObject(ItemInfo[playerid][item_object])) {
		DestroyDynamicObject(ItemInfo[playerid][item_object]);
	}
	ItemInfo[playerid][item_object] = CreateDynamicObject(19789, ItemInfo[playerid][item_x], ItemInfo[playerid][item_y], DEFAULT_Z, 0.0, 0.0, 0.0, DEFAULT_VWORLD, 0, playerid);
	switch(random(5)) {
		case 0: SetDynamicObjectMaterial(ItemInfo[playerid][item_object], 0, 8839, "vgsecarshow", "lightblue2_32", 0xFFFFFFFF);
		case 1: SetDynamicObjectMaterial(ItemInfo[playerid][item_object], 0, 8839, "vgsecarshow", "lightblue_64", 0xFFFFFFFF);
		case 2: SetDynamicObjectMaterial(ItemInfo[playerid][item_object], 0, 8839, "vgsecarshow", "lightgreen2_32", 0xFFFFFFFF);
		case 3: SetDynamicObjectMaterial(ItemInfo[playerid][item_object], 0, 8839, "vgsecarshow", "lightpurple2_32", 0xFFFFFFFF);
		case 4: SetDynamicObjectMaterial(ItemInfo[playerid][item_object], 0, 8839, "vgsecarshow", "lightred2_32", 0xFFFFFFFF);
	}
}

stock CreateBarrier(playerid) {
	if(PlayerInfo[playerid][player_barrier]) {
		for(new a; a < MAX_BARRIER_SIZE; a++) {
			// Генерация
			create: {
				// Позиция
				BarrierInfo[playerid][a][barrier_x] = DEFAULT_X + 2.0 + random(MAX_ZONE_WIDTH - 4);
				BarrierInfo[playerid][a][barrier_y] = DEFAULT_Y + 2.0 + random(MAX_ZONE_HEIGHT - 4);

				// Проверка на барьеры
				for(new b; b < a; b++) {
					if((BarrierInfo[playerid][a][barrier_x] == BarrierInfo[playerid][b][barrier_x] || BarrierInfo[playerid][a][barrier_x] == (BarrierInfo[playerid][b][barrier_x] + 1.0))
					&& (BarrierInfo[playerid][a][barrier_y] == BarrierInfo[playerid][b][barrier_y] || BarrierInfo[playerid][a][barrier_y] == (BarrierInfo[playerid][b][barrier_y] - 1.0))) {
						goto create;
					}
				}

				// Проверка на змейку
				for(new i = SnakeSize[playerid]; i >= 0; i--) {
					if(BarrierInfo[playerid][a][barrier_x] == SnakeInfo[playerid][i][snake_x]
					&& BarrierInfo[playerid][a][barrier_y] == SnakeInfo[playerid][i][snake_y]) {
						goto create;
					}
				}

				// Проверка перед головой
				if(BarrierInfo[playerid][a][barrier_x] == (SnakeInfo[playerid][0][snake_x] + 1.0)
				&& BarrierInfo[playerid][a][barrier_y] == SnakeInfo[playerid][0][snake_y]) {
					goto create;
				}

				// Проверка на предмет
				if(BarrierInfo[playerid][a][barrier_x] == ItemInfo[playerid][item_x]
				&& BarrierInfo[playerid][a][barrier_y] == ItemInfo[playerid][item_y]) {
					goto create;
				}
			}

			// Пересоздание объекта
			if(IsValidDynamicObject(BarrierInfo[playerid][a][barrier_object])) {
				DestroyDynamicObject(BarrierInfo[playerid][a][barrier_object]);
			}
			BarrierInfo[playerid][a][barrier_object] = CreateDynamicObject(19789, BarrierInfo[playerid][a][barrier_x], BarrierInfo[playerid][a][barrier_y], DEFAULT_Z, 0.0, 0.0, 0.0, DEFAULT_VWORLD, 0, playerid);
			SetDynamicObjectMaterial(BarrierInfo[playerid][a][barrier_object], 0, 10931, "traingen_sfse", "metpat64", 0xFFFFFFFF);
		}
	}
}

stock GetSnakeScore(playerid) {
	if(PlayerInfo[playerid][player_start]) {
		return SnakeSize[playerid] - DEFAULT_SIZE;
	}
	return 0;
}

stock GetSnakeMaxScore(playerid) {
	if(PlayerInfo[playerid][player_start]) {
		if(PlayerInfo[playerid][player_barrier]) {
			return MAX_SNAKE_SIZE - MAX_BARRIER_SIZE;
		}
		return MAX_SNAKE_SIZE;
	}
	return 0;
}

stock UpdatePlayerCamera(playerid) {
	new Float:angle;
	Streamer_GetFloatData(STREAMER_TYPE_OBJECT, SnakeInfo[playerid][0][snake_object], E_STREAMER_R_Z, angle);

	// Камера
	SetPlayerCameraPos(playerid, SnakeInfo[playerid][0][snake_x] + (2.5 * floatsin(-angle, degrees)), SnakeInfo[playerid][0][snake_y] + (2.5 * floatcos(-angle, degrees)), (DEFAULT_Z + 2.0));
	SetPlayerCameraLookAt(playerid, SnakeInfo[playerid][0][snake_x] + (-5.0 * floatsin(-angle, degrees)), SnakeInfo[playerid][0][snake_y] + (-5.0 * floatcos(-angle, degrees)), (DEFAULT_Z + 0.5), 2);

	// Счет
	SetDynamicObjectPos(ZoneText[playerid], SnakeInfo[playerid][0][snake_x] + (1.2 * floatsin(-angle, degrees)), SnakeInfo[playerid][0][snake_y] + (1.2 * floatcos(-angle, degrees)), (DEFAULT_Z + 1.15));
	SetDynamicObjectRot(ZoneText[playerid], 0.0, -15.0, angle + 90.0);
}

forward OnPlayerSnakeUpdate(playerid);
public OnPlayerSnakeUpdate(playerid) {
	if(PlayerInfo[playerid][player_start]) {
		if(!PlayerInfo[playerid][player_pause]) {
			if(GetTickCount() - PlayerInfo[playerid][player_afk] > 1000) {
				PlayerInfo[playerid][player_pause] = true;
			} else {
				// Движение
				for(new i = SnakeSize[playerid]; i > 0; i--) {
					SnakeInfo[playerid][i][snake_x] = SnakeInfo[playerid][i - 1][snake_x];
					SnakeInfo[playerid][i][snake_y] = SnakeInfo[playerid][i - 1][snake_y];
					SnakeInfo[playerid][i][snake_collision] = SnakeInfo[playerid][i - 1][snake_collision];
				}
				if(PlayerInfo[playerid][player_key1] == 0) {
					SnakeInfo[playerid][0][snake_y] += 1.0;
				} else if(PlayerInfo[playerid][player_key1] == 1) {
					SnakeInfo[playerid][0][snake_y] -= 1.0;
				} else if(PlayerInfo[playerid][player_key1] == 2) {
					SnakeInfo[playerid][0][snake_x] -= 1.0;
				} else if(PlayerInfo[playerid][player_key1] == 3) {
					SnakeInfo[playerid][0][snake_x] += 1.0;
				}
				PlayerInfo[playerid][player_key2] = PlayerInfo[playerid][player_key1];

				// Проверка на выход за пределы
				if(PlayerInfo[playerid][player_collision]) {
					if(SnakeInfo[playerid][0][snake_x] > (MAX_ZONE_WIDTH + DEFAULT_X - 2.0)) {
						SnakeInfo[playerid][0][snake_x] = DEFAULT_X + 1.0;
						SnakeInfo[playerid][0][snake_collision] = true;
					} else if(SnakeInfo[playerid][0][snake_x] < (DEFAULT_X + 1.0)) {
						SnakeInfo[playerid][0][snake_x] = MAX_ZONE_WIDTH + DEFAULT_X - 2.0;
						SnakeInfo[playerid][0][snake_collision] = true;
					} else if(SnakeInfo[playerid][0][snake_y] > (MAX_ZONE_HEIGHT + DEFAULT_Y - 2.0)) {
						SnakeInfo[playerid][0][snake_y] = DEFAULT_Y + 1.0;
						SnakeInfo[playerid][0][snake_collision] = true;
					} else if(SnakeInfo[playerid][0][snake_y] < (DEFAULT_Y + 1.0)) {
						SnakeInfo[playerid][0][snake_y] = MAX_ZONE_HEIGHT + DEFAULT_Y - 2.0;
						SnakeInfo[playerid][0][snake_collision] = true;
					} else {
						SnakeInfo[playerid][0][snake_collision] = false;
					}
				} else {
					if(SnakeInfo[playerid][0][snake_x] > (MAX_ZONE_WIDTH + DEFAULT_X - 2.0)
					|| SnakeInfo[playerid][0][snake_x] < (DEFAULT_X + 1.0)
					|| SnakeInfo[playerid][0][snake_y] > (MAX_ZONE_HEIGHT + DEFAULT_Y - 2.0)
					|| SnakeInfo[playerid][0][snake_y] < (DEFAULT_Y + 1.0)) {
						SetDynamicObjectMaterialText(ZoneText[playerid], 0, "Game Over", 40, "Ariel", 25, 1, 0xFFDC143C, 0, 1);
						KillTimer(PlayerInfo[playerid][player_timer]);
						PlayerInfo[playerid][player_timer] = 0;
						PlayerPlaySound(playerid, 14408, 0.0, 0.0, 0.0);
						new string[36];
						format(string, sizeof(string), "Вы проиграли, ваш счет: %d", GetSnakeScore(playerid));
						ShowPlayerDialog(playerid, DEFAULT_DIALOGID + 2, DIALOG_STYLE_MSGBOX, "Поражение", string, "Рестарт", "Выход");
					}
				}

				// Проверка на столкновение с хвостом
				if(SnakeSize[playerid] > 4) {
					for(new i = SnakeSize[playerid] - 1; i > 0; i--) {
						if(SnakeInfo[playerid][0][snake_x] == SnakeInfo[playerid][i][snake_x]
						&& SnakeInfo[playerid][0][snake_y] == SnakeInfo[playerid][i][snake_y]) {
							SetDynamicObjectMaterialText(ZoneText[playerid], 0, "Game Over", 40, "Ariel", 25, 1, 0xFFDC143C, 0, 1);
							KillTimer(PlayerInfo[playerid][player_timer]);
							PlayerInfo[playerid][player_timer] = 0;
							PlayerPlaySound(playerid, 14408, 0.0, 0.0, 0.0);
							new string[36];
							format(string, sizeof(string), "Вы проиграли, ваш счет: %d", GetSnakeScore(playerid));
							ShowPlayerDialog(playerid, DEFAULT_DIALOGID + 2, DIALOG_STYLE_MSGBOX, "Поражение", string, "Рестарт", "Выход");
						}
					}
				}

				// Проверка на столкновение с барьером
				if(PlayerInfo[playerid][player_barrier]) {
					for(new i; i < MAX_BARRIER_SIZE; i++) {
						if(SnakeInfo[playerid][0][snake_x] == BarrierInfo[playerid][i][barrier_x]
						&& SnakeInfo[playerid][0][snake_y] == BarrierInfo[playerid][i][barrier_y]) {
							SetDynamicObjectMaterialText(ZoneText[playerid], 0, "Game Over", 40, "Ariel", 25, 1, 0xFFDC143C, 0, 1);
							KillTimer(PlayerInfo[playerid][player_timer]);
							PlayerInfo[playerid][player_timer] = 0;
							PlayerPlaySound(playerid, 14408, 0.0, 0.0, 0.0);
							new string[36];
							format(string, sizeof(string), "Вы проиграли, ваш счет: %d", GetSnakeScore(playerid));
							ShowPlayerDialog(playerid, DEFAULT_DIALOGID + 2, DIALOG_STYLE_MSGBOX, "Поражение", string, "Рестарт", "Выход");
						}
					}
				}

				// Ищем предмет
				if(SnakeInfo[playerid][0][snake_x] == ItemInfo[playerid][item_x]
				&& SnakeInfo[playerid][0][snake_y] == ItemInfo[playerid][item_y]) {
					// Добавление очков
					SnakeSize[playerid]++;
					// Проверка на уровень
					if(SnakeSize[playerid] >= GetSnakeMaxScore(playerid)) {
						SetDynamicObjectMaterialText(ZoneText[playerid], 0, "Победа!", 40, "Ariel", 25, 1, 0xFF32CD32, 0, 1);
						KillTimer(PlayerInfo[playerid][player_timer]);
						PlayerInfo[playerid][player_timer] = 0;
						PlayerPlaySound(playerid, 31205, 0.0, 0.0, 0.0);
						new string[35];
						format(string, sizeof(string), "Вы победили, ваш счет: %d", GetSnakeScore(playerid));
						ShowPlayerDialog(playerid, DEFAULT_DIALOGID + 2, DIALOG_STYLE_MSGBOX, "Победа", string, "Рестарт", "Выход");
					} else {
						CreateItem(playerid);
						PlayerPlaySound(playerid, 21002, 0.0, 0.0, 0.0);
					}
				}

				// Обновление игры
				if(PlayerInfo[playerid][player_timer]) {
					for(new i; i < SnakeSize[playerid]; i++) {
						// Перемещаем & создаем
						if(IsValidDynamicObject(SnakeInfo[playerid][i][snake_object])) {
							new Float:angle;
							if(SnakeInfo[playerid][i][snake_oldx] < SnakeInfo[playerid][i][snake_x]) { // right
								angle = 90.0;
							} else if(SnakeInfo[playerid][i][snake_oldx] > SnakeInfo[playerid][i][snake_x]) { // left
								angle = -90.0;
							} else if(SnakeInfo[playerid][i][snake_oldy] < SnakeInfo[playerid][i][snake_y]) { // up
								angle = 180.0;
							} else { // down
								angle = 0.0;
							}
							if(SnakeInfo[playerid][i][snake_collision]) {
								angle += 180.0;
							}
							SetDynamicObjectPos(SnakeInfo[playerid][i][snake_object], SnakeInfo[playerid][i][snake_x], SnakeInfo[playerid][i][snake_y], DEFAULT_Z);
							SetDynamicObjectRot(SnakeInfo[playerid][i][snake_object], 0.0, 0.0, angle);
						} else {
							SnakeInfo[playerid][i][snake_object] = CreateDynamicObject(19789, SnakeInfo[playerid][i][snake_x], SnakeInfo[playerid][i][snake_y], DEFAULT_Z, 0.0, 0.0, 0.0, DEFAULT_VWORLD, 0, playerid);
							SetDynamicObjectMaterial(SnakeInfo[playerid][i][snake_object], 0, 8538, "vgsrailroad", "concreteyellow256 copy", 0xFFFFFFFF);
						}

						// Записываем старую позицию
						SnakeInfo[playerid][i][snake_oldx] = SnakeInfo[playerid][i][snake_x];
						SnakeInfo[playerid][i][snake_oldy] = SnakeInfo[playerid][i][snake_y];
					}

					// Обновление счета
					new string[18];
					format(string, sizeof(string), "Счет: %d", GetSnakeScore(playerid));
					SetDynamicObjectMaterialText(ZoneText[playerid], 0, string, 40, "Ariel", 25, 1, 0xFFFFFFFF, 0, 1);

					// Обновление камеры & позиции счета
					if(PlayerInfo[playerid][player_fperson]) {
						UpdatePlayerCamera(playerid);
					}

					// Обновление объектов
					Streamer_Update(playerid, STREAMER_TYPE_OBJECT);
				}
			}
		} else {
			SetDynamicObjectMaterialText(ZoneText[playerid], 0, "Пауза", 40, "Ariel", 25, 1, 0xFF0000CD, 0, 1);
		}
	}
}
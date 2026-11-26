/* Steam Controller bridge for the media kiosk.
 *
 * The 2026 Steam Controller speaks its vendor protocol through the puck's
 * hidraw interfaces. The m920q runs the ZFS-supported 6.18 kernel, whose
 * hid-steam does not know this controller, so the firmware's lizard mode only
 * exposes keyboard/mouse interfaces: the real sticks, the Steam button and the
 * QAM (three-dot) button never reach the host. SDL3's Triton driver claims the
 * vendor interfaces and disables lizard mode; this daemon turns the resulting
 * gamepad state into the keys and API calls the kiosk already understands.
 * Steam opens the surface switcher (a walker dmenu over the live windows) so
 * AirPlay, Cinejoy, the kiosk shell and Moonlight can be focused without
 * closing each other. QAM is the quick volume control: tap it to mute, or hold
 * it and move the stick/D-pad to step the sink volume. The sticks and D-pad
 * otherwise feed the page's arrow-key navigation, and B stays a plain Escape.
 * The double-B close shortcut belongs to the lizard-mode fallback in
 * server.py, where the Steam and QAM buttons never reach the host.
 *
 * Volume steps call avizo's volumectl; its OSD is a layer-shell overlay with
 * keyboard interactivity off, so it stays visible over the fullscreen kiosk
 * and app windows without taking focus.
 *
 * wtype is used instead of a virtual gamepad so the same mapping reaches
 * whichever window is focused (kiosk shell, Cinejoy, Jellyfin, Immich), not
 * just the kiosk page. The unit is bound to the kiosk browser, so exiting the
 * kiosk hands the controller back to lizard mode; it starts after
 * niri-session.target, which exports WAYLAND_DISPLAY.
 */
#include <SDL3/SDL.h>
#include <curl/curl.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifndef WTYPE_BIN
#define WTYPE_BIN "wtype"
#endif

#ifndef VOLUMECTL_BIN
#define VOLUMECTL_BIN "volumectl"
#endif

#define AXIS_DEADZONE 20000
#define MOVE_REPEAT_MS 180
#define VOLUME_REPEAT_MS 200
#define QAM_TAP_MS 500
#define POLL_MS 16

static const char *api_base = "http://127.0.0.1:8790";
static SDL_Gamepad *pad;
static Uint64 last_move;
static Uint64 last_scan;
static Uint64 qam_pressed_at;
static Uint64 last_volume;
static int prev_dx;
static int prev_dy;
static int prev_volume_dir;
static bool suppress_move;
static bool qam_used;
static bool prev_a;
static bool prev_b;
static bool prev_steam;
static bool prev_qam;

static void send_key(const char *key) {
  pid_t pid = fork();

  if (pid == 0) {
    execl(WTYPE_BIN, "wtype", "-k", key, (char *)NULL);
    _exit(127);
  }
  if (pid < 0) {
    fprintf(stderr, "controller: fork failed\n");
  }
}

static void run_volumectl(const char *arg1, const char *arg2) {
  pid_t pid = fork();

  if (pid == 0) {
    if (arg2 != NULL) {
      execl(VOLUMECTL_BIN, "volumectl", arg1, arg2, (char *)NULL);
    } else {
      execl(VOLUMECTL_BIN, "volumectl", arg1, (char *)NULL);
    }
    _exit(127);
  }
  if (pid < 0) {
    fprintf(stderr, "controller: fork failed\n");
  }
}

static void kiosk_post(const char *path) {
  char url[512];
  struct curl_slist *headers = NULL;
  CURL *curl = curl_easy_init();
  CURLcode result;

  if (curl == NULL) {
    fprintf(stderr, "controller: curl init failed\n");
    return;
  }

  snprintf(url, sizeof(url), "%s%s", api_base, path);
  headers = curl_slist_append(headers, "Content-Type: application/json");
  headers = curl_slist_append(headers, "X-Kiosk-Request: 1");
  curl_easy_setopt(curl, CURLOPT_URL, url);
  curl_easy_setopt(curl, CURLOPT_POSTFIELDS, "{}");
  curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
  curl_easy_setopt(curl, CURLOPT_TIMEOUT, 5L);
  result = curl_easy_perform(curl);
  if (result != CURLE_OK) {
    fprintf(stderr, "controller: POST %s failed: %s\n", path,
            curl_easy_strerror(result));
  }

  curl_slist_free_all(headers);
  curl_easy_cleanup(curl);
}

static void reset_state(void) {
  pad = NULL;
  prev_dx = 0;
  prev_dy = 0;
  prev_volume_dir = 0;
  suppress_move = false;
  qam_used = false;
  prev_a = false;
  prev_b = false;
  prev_steam = false;
  prev_qam = false;
}

static void try_open_pad(void) {
  int count = 0;
  SDL_JoystickID *ids;

  if (pad != NULL) {
    return;
  }
  ids = SDL_GetGamepads(&count);
  if (ids == NULL) {
    return;
  }
  if (count > 0) {
    pad = SDL_OpenGamepad(ids[0]);
    if (pad != NULL) {
      fprintf(stderr, "controller: connected (%s)\n", SDL_GetGamepadName(pad));
    }
  }
  SDL_free(ids);
}

static void poll_pad(Uint64 now) {
  int left_x = SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_LEFTX);
  int left_y = SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_LEFTY);
  int right_x = SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_RIGHTX);
  int right_y = SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_RIGHTY);
  bool dpad_up = SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_DPAD_UP);
  bool dpad_down = SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_DPAD_DOWN);
  bool dpad_left = SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_DPAD_LEFT);
  bool dpad_right = SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_DPAD_RIGHT);
  bool a = SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_SOUTH);
  bool b = SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_EAST);
  bool steam = SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_GUIDE);
  bool qam = SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_MISC1);
  int x = abs(left_x) >= abs(right_x) ? left_x : right_x;
  int y = abs(left_y) >= abs(right_y) ? left_y : right_y;
  int dx = 0;
  int dy = 0;
  int volume_dir = 0;

  if (dpad_up || y < -AXIS_DEADZONE) {
    dy = -1;
  }
  if (dpad_down || y > AXIS_DEADZONE) {
    dy = 1;
  }
  if (dpad_left || x < -AXIS_DEADZONE) {
    dx = -1;
  }
  if (dpad_right || x > AXIS_DEADZONE) {
    dx = 1;
  }
  if (dx != 0 && dy != 0) {
    if (abs(x) > abs(y)) {
      dy = 0;
    } else {
      dx = 0;
    }
  }

  if (qam) {
    if (!prev_qam) {
      qam_pressed_at = now;
      qam_used = false;
      prev_volume_dir = 0;
      last_volume = 0;
    }
    volume_dir = dy;
    if (volume_dir != 0 &&
        (volume_dir != prev_volume_dir ||
         now - last_volume >= VOLUME_REPEAT_MS)) {
      run_volumectl("-u", volume_dir < 0 ? "up" : "down");
      last_volume = now;
      qam_used = true;
    }
    prev_volume_dir = volume_dir;
    suppress_move = true;
  } else if (prev_qam) {
    if (!qam_used && now - qam_pressed_at <= QAM_TAP_MS) {
      run_volumectl("toggle-mute", NULL);
    }
    qam_used = false;
    prev_volume_dir = 0;
    last_volume = 0;
  }

  if (suppress_move) {
    if (dx == 0 && dy == 0) {
      suppress_move = false;
    }
  } else if ((dx != 0 || dy != 0) &&
             (dx != prev_dx || dy != prev_dy ||
              now - last_move >= MOVE_REPEAT_MS)) {
    send_key(dx < 0 ? "Left" : dx > 0 ? "Right" : dy < 0 ? "Up" : "Down");
    last_move = now;
  }
  prev_dx = dx;
  prev_dy = dy;

  if (!qam) {
    if (a && !prev_a) {
      send_key("Return");
    }
    if (b && !prev_b) {
      send_key("Escape");
    }
    if (steam && !prev_steam) {
      kiosk_post("/api/switcher");
    }
  }
  prev_a = a;
  prev_b = b;
  prev_steam = steam;
  prev_qam = qam;
}

int main(void) {
  SDL_Event event;
  const char *env;
  bool running = true;

  signal(SIGCHLD, SIG_IGN);
  setvbuf(stderr, NULL, _IOLBF, 0);

  env = getenv("KIOSK_API");
  if (env != NULL && env[0] != '\0') {
    api_base = env;
  }

  curl_global_init(CURL_GLOBAL_DEFAULT);
  SDL_SetHint(SDL_HINT_JOYSTICK_HIDAPI, "1");
  SDL_SetHint(SDL_HINT_JOYSTICK_HIDAPI_STEAM, "1");
  SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");
  if (!SDL_Init(SDL_INIT_GAMEPAD)) {
    fprintf(stderr, "controller: SDL init failed: %s\n", SDL_GetError());
    curl_global_cleanup();
    return 1;
  }

  try_open_pad();
  if (pad == NULL) {
    fprintf(stderr, "controller: waiting for a Steam Controller\n");
  }

  while (running) {
    Uint64 now = SDL_GetTicks();

    while (SDL_PollEvent(&event)) {
      if (event.type == SDL_EVENT_QUIT) {
        running = false;
      } else if (event.type == SDL_EVENT_GAMEPAD_ADDED) {
        try_open_pad();
      } else if (event.type == SDL_EVENT_GAMEPAD_REMOVED && pad != NULL &&
                 event.gdevice.which == SDL_GetGamepadID(pad)) {
        fprintf(stderr, "controller: disconnected\n");
        SDL_CloseGamepad(pad);
        reset_state();
      }
    }
    if (pad != NULL) {
      poll_pad(now);
    } else if (now - last_scan >= 1000) {
      last_scan = now;
      try_open_pad();
    }
    SDL_Delay(POLL_MS);
  }

  if (pad != NULL) {
    SDL_CloseGamepad(pad);
  }
  SDL_Quit();
  curl_global_cleanup();
  return 0;
}

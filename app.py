import os

os.environ.setdefault("POCKETDM_TTS_PRELOAD", "1")

from app.server import app

if __name__ == "__main__":
    app.launch(server_name="0.0.0.0", server_port=7860)

# Exercises the binary file effects: writes a byte payload, reads it back,
# and confirms a missing path reports NotFound. The round-trip happens in
# init!, so a failure exits before any window content appears.
app [Model, program] { rr: platform "https://github.com/lukewilliamboswell/roc-ray/releases/download/0.9.0/3sKTYuHvxSV77dDyZrxuUYgfrAarL6ZtasWMPeH32udh.tar.zst" }

import rr.App
import rr.Color
import rr.Draw
import rr.Host
import rr.Text

Model : {
	status : Text.Prepared,
}

roundtrip_path : Str
roundtrip_path = "examples/assets/file_io_roundtrip.bin"

payload : List(U8)
payload = [0, 1, 2, 3, 127, 128, 200, 254, 255, 0, 66]

program = { init!, render! }

init! : App.Init(Model, [ResourceLimit, WriteFailed, NotFound, ReadFailed, RoundTripMismatch, ExpectedNotFound])
init! = App.init(
	App.default.with_title("RocRay file io").with_size({ width: 480, height: 200 }),
	|host| {
		host.write_bytes!(roundtrip_path, payload)?
		echoed = host.read_bytes!(roundtrip_path)?
		if echoed == payload {
			match host.read_bytes!("examples/assets/no_such_file.bin") {
				Err(NotFound) => Ok({ status: Text.from("file io round-trip ok").size(24).prepare!()? })
				Ok(_) => Err(ExpectedNotFound)
				Err(_) => Err(ExpectedNotFound)
			}
		} else {
			Err(RoundTripMismatch)
		}
	},
)

render! : Model, Host, Draw.Frame => Try(Model, [Exit(I64), ..])
render! = |model, host, frame| {
	if host.key_pressed(KeyEscape) {
		host.exit!(0)
	}

	frame.clear!(Color.from_hex_rgb(0x0d1425))
	model.status.draw!(frame, { pos: { x: 240, y: 88 }, color: Color.white, align: Text.align_top_center })

	Ok(model)
}

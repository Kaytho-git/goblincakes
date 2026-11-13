// A planet like Saturn (the splash, 13 Nov – the user: "en planet som kommer in från bakgrunden som ser ut som Saturnus"):
// a banded golden ball with tilted rings, the far half of the rings behind the ball and the near half in front.
// Drawn once at full size; the splash moves it in by scale.
import QtQuick

Item {
    id: saturn
    // the glow around it
    Repeater {
        model: 5
        Rectangle {
            required property int index
            anchors.centerIn: parent
            width: saturn.width * (0.78 - index * 0.08); height: width; radius: width / 2
            color: "#FFD9A0"
            opacity: 0.03 + index * 0.012
        }
    }
    Canvas {
        id: art
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const w = width, cx = w / 2, cy = height / 2;
            const r = w * 0.22;                  // the ball
            const squash = 0.3;                  // the rings seen from a little above
            const tilt = -0.32;                  // radians
            const rings = [
                { rad: w * 0.47, width: w * 0.025, color: "#C9A46A", alpha: 0.55 },
                { rad: w * 0.43, width: w * 0.045, color: "#E9D2A2", alpha: 0.85 },
                { rad: w * 0.385, width: w * 0.03, color: "#B8915A", alpha: 0.7 },
                { rad: w * 0.345, width: w * 0.035, color: "#F2E1BC", alpha: 0.8 },
                { rad: w * 0.305, width: w * 0.02, color: "#A07A48", alpha: 0.45 }
            ];
            function ringHalf(start, end) {
                c.save();
                c.translate(cx, cy);
                c.rotate(tilt);
                c.scale(1, squash);
                for (let i = 0; i < rings.length; i++) {
                    c.beginPath();
                    c.globalAlpha = rings[i].alpha;
                    c.strokeStyle = rings[i].color;
                    c.lineWidth = rings[i].width;
                    c.arc(0, 0, rings[i].rad, start, end, false);
                    c.stroke();
                }
                c.restore();
                c.globalAlpha = 1;
            }
            ringHalf(Math.PI, Math.PI * 2);      // the far half, behind

            // the ball, lit from the upper left
            const g = c.createRadialGradient(cx - r * 0.45, cy - r * 0.5, r * 0.1, cx, cy, r * 1.05);
            g.addColorStop(0, "#FFF1C9");
            g.addColorStop(0.35, "#F0C980");
            g.addColorStop(0.75, "#C98E48");
            g.addColorStop(1, "#6E4423");
            c.beginPath();
            c.arc(cx, cy, r, 0, Math.PI * 2);
            c.fillStyle = g;
            c.fill();
            // its bands, along the rings' tilt
            c.save();
            c.beginPath();
            c.arc(cx, cy, r, 0, Math.PI * 2);
            c.clip();
            c.translate(cx, cy);
            c.rotate(tilt);
            const bands = [[-0.62, 0.1, "#FFF4D6"], [-0.38, 0.13, "#B97E3E"], [-0.12, 0.08, "#FBE3B0"],
                           [0.1, 0.16, "#A86F35"], [0.36, 0.09, "#F6D9A0"], [0.58, 0.12, "#9A6430"]];
            for (let i = 0; i < bands.length; i++) {
                c.globalAlpha = 0.35;
                c.fillStyle = bands[i][2];
                c.fillRect(-r * 1.2, bands[i][0] * r, r * 2.4, bands[i][1] * r);
            }
            c.globalAlpha = 1;
            // night side
            const shade = c.createLinearGradient(-r, -r, r, r);
            shade.addColorStop(0.45, "rgba(0,0,0,0)");
            shade.addColorStop(1, "rgba(5,8,25,0.55)");
            c.fillStyle = shade;
            c.fillRect(-r * 1.2, -r * 1.2, r * 2.4, r * 2.4);
            c.restore();

            ringHalf(0, Math.PI);                // the near half, in front
        }
    }
}

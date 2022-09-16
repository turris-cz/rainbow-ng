PREFIX := /usr

all:

install: rainbow-install button-sync-install animator-install

rainbow-install:
	install -D -m 644 rainbow/animation.sh ${DESTDIR}${PREFIX}/libexec/rainbow/animation.sh
	install -D -m 644 rainbow/brightness.sh ${DESTDIR}${PREFIX}/libexec/rainbow/brightness.sh
	install -D -m 644 rainbow/color.sh ${DESTDIR}${PREFIX}/libexec/rainbow/color.sh
	install -D -m 644 rainbow/compat.sh ${DESTDIR}${PREFIX}/libexec/rainbow/compat.sh
	install -D -m 644 rainbow/led.sh ${DESTDIR}${PREFIX}/libexec/rainbow/led.sh
	install -D -m 644 rainbow/led_activity.sh ${DESTDIR}${PREFIX}/libexec/rainbow/led_activity.sh
	install -D -m 644 rainbow/led_animate.sh ${DESTDIR}${PREFIX}/libexec/rainbow/led_animate.sh
	install -D -m 644 rainbow/ledid.sh ${DESTDIR}${PREFIX}/libexec/rainbow/ledid.sh
	install -D -m 644 rainbow/pci.sh ${DESTDIR}${PREFIX}/libexec/rainbow/pci.sh
	install -D -m 644 rainbow/reset.sh ${DESTDIR}${PREFIX}/libexec/rainbow/reset.sh
	install -D -m 644 rainbow/state.sh ${DESTDIR}${PREFIX}/libexec/rainbow/state.sh
	install -D -m 644 rainbow/uci.sh ${DESTDIR}${PREFIX}/libexec/rainbow/uci.sh
	install -D -m 644 rainbow/utils.sh ${DESTDIR}${PREFIX}/libexec/rainbow/utils.sh
	install -D -m 755 rainbow/rainbow.sh ${DESTDIR}${PREFIX}/libexec/rainbow/rainbow.sh
	mkdir -p ${DESTDIR}${PREFIX}/bin
	ln -sf ${PREFIX}/libexec/rainbow/rainbow.sh ${DESTDIR}${PREFIX}/bin/rainbow

button-sync-install:
	install -D -m 644 button-sync/button_sync.sh ${DESTDIR}${PREFIX}/libexec/rainbow/button_sync.sh

animator-install:
	install -D -m 755 animator/animator.py ${DESTDIR}${PREFIX}/libexec/rainbow/animator.py

mox-install:
	install -D -m 644 backend/mox/animator_backend.py ${DESTDIR}${PREFIX}/libexec/rainbow/animator_backend.py
	install -D -m 644 backend/mox/backend.sh ${DESTDIR}${PREFIX}/libexec/rainbow/backend.sh

omnia-install:
	install -D -m 644 backend/omnia/animator_backend.py ${DESTDIR}${PREFIX}/libexec/rainbow/animator_backend.py
	install -D -m 644 backend/omnia/backend.sh ${DESTDIR}${PREFIX}/libexec/rainbow/backend.sh

turris1x-install:
	install -D -m 644 backend/turris1x/animator_backend.py ${DESTDIR}${PREFIX}/libexec/rainbow/animator_backend.py
	install -D -m 644 backend/turris1x/backend.sh ${DESTDIR}${PREFIX}/libexec/rainbow/backend.sh

.PHONY: all install rainbow-install button-sync-install animator-install mox-install omnia-install turris1x-install

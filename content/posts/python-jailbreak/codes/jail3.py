import sys

def profiler(frame, event, arg):
    print(f"{frame}, {event}, {arg}")
    return profiler

import homework

sys.setprofile(profiler)
homework.answer()
a = [1, 2, 3]
b = a[1]

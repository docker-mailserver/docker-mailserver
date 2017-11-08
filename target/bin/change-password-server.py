#!/usr/bin/python

from flask import Flask, request, make_response, abort
from subprocess import Popen, PIPE
import os
import time

app = Flask(__name__)
update_mail_user_cmd = os.getenv('UPDATEMAILUSER_SECURE', 'sudo updatemailuser-secure').split()

@app.route("/change-password", methods=['POST'])
def change_password():
    json = request.get_json()
    if json is None:
        abort(400)
    try:
        user = json['user']
        old_password = json['oldPassword']
        new_password = json['newPassword']
        # Call "updatemailuser-secure" and pass the passwords through stdin
        proc = Popen(update_mail_user_cmd + [user], stdin=PIPE, stdout=PIPE, stderr=PIPE)
        print repr(proc.communicate(input=old_password + '\n' + new_password + '\n'))
        exit_code = proc.wait()
        print "exit_code: " + repr(exit_code)
        if exit_code == 0:
            return 'Passwort successfully changed'
        elif exit_code == 2:
            time.sleep(3)
            return 'Invalid credentials', 403
    except KeyError as err:
        print repr(err)
        abort(400)
    except BaseException as err:
        print repr(err)
    else:
        print "updatemailuser-secure exited with code " + repr(exit_code)
        abort(500)


app.run(host="0.0.0.0", port=5000)

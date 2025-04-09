# ssl inspection issue

if you're in an environment where SSL inspection on the firewall is blocking access to pypi.org and you can't install libraries in your python venv as a result, try this line:

pip install --trusted-host=pypi.org --trusted-host=files.pythonhosted.org --user {name of whatever you're installing}

# running python from powershell terminal

* ensure python is installed and environment variables are set-up correctly, google for this
* when running a python file from powershell, either `cd` to the directory the file is in and run `python3 <nameoffile.py>`, or run `python3 "c:\entire\file\path\nameoffile.py"`
* you can also trigger it from cmd prompt if you're feeling frisky with `cmd /k python3 nameoffile.py`
* i'm just assuming you'll be installing python3 and want to use python3 to call it in the year 2025 but whatever you can also just use python

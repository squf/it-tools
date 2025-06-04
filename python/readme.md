I made a thing I am calling docCobbler, it cobbles together a bunch of .docx files and extracts some data from screenshots embedded in these files and spits them out into a single file to make it easier to review.

steps i took:

1. open debian in wsl2
2. make venv for python `python3 -m venv doccobbler`
3. start venv `source doccobbler/bin/activate`
4. install packages to venv (note: in my environment i have to bypass ssl inspection on the firewall) -> `pip install --trusted-host=pypi.org --trusted-host=files.pythonhosted.org python-docx` && repeat for `pytesseract`,`pillow`,`pandas`,`openpyxl`
5. install tesseract separately `sudo apt update` && `sudo apt install tesseract-ocr` && verify `tesseract --version`
6. i then ran my script and it worked perfectly, i did not have to update my $PATH variable to point to tesseract, however if i did have to that would just be a simple edit to ~/.bashrc --> `export PATH="$PATH:/to/tesseract/location` and then edit the script to include that

* the script worked perfectly to combine all of the .docx files into one big .docx file which is what i wanted, but i'm going to work on a separate script from here to clean it up and only extract the elements i want

 * i'll upload `docCobbler.py` and `docCobblerCleanup.py` separately to this repo - the `docCobbler.py` is the primary script which will combine all .docx files to one big file (edit the path to match your environment!)

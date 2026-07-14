import os
from pathlib import Path
import pathlib
from dotenv import load_dotenv
from ipumspy import IpumsApiClient, MicrodataExtract, readers, ddi

load_dotenv()

try:
    IPUMS_API_KEY = os.environ.get("IPUMS_API_KEY")
    ipums = IpumsApiClient(IPUMS_API_KEY)
except:
    print("create account and get your api key at the link below: \n https://account.ipums.org/api_keys")
    raise ValueError("IPUMS_API_KEY not found in environment variables. Please set it in your .env file.")

data_dir = pathlib.Path('data')

if not os.path.isdir(data_dir):
    os.makedirs(data_dir, exist_ok=True)

if len(os.listdir(data_dir)) <= 0:
    extract = MicrodataExtract(
        collection='cps',
        samples=['cps2024_03s','cps2019_03s'], 
        variables=['AGE','SEX','EDUC','EMPSTAT','LABFORCE', 'OCC','IND','INCWAGE','ASECWT']
    )
    ipums.submit_extract(extract)                           # Submit the extract request
    print(f"Extract submitted with id {extract.extract_id}")

    ipums.wait_for_extract(extract)                         # Wait for the extract to finish

    ipums.download_extract(extract, download_dir='data/')   # Download the extract
    print(f"Extract downloaded to {data_dir}")
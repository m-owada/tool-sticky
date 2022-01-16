using System;
using System.Collections.Generic;
using System.Data.SQLite;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web;
using System.Web.WebSockets;
using System.Net.WebSockets;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion ("1.0.0.0")]
[assembly: AssemblyInformationalVersion("1.0")]
[assembly: AssemblyTitle("")]
[assembly: AssemblyDescription("")]
[assembly: AssemblyProduct("Sticky Notes")]
[assembly: AssemblyCompany("")]
[assembly: AssemblyCopyright("Copyright (c) 2022 m-owada.")]
[assembly: AssemblyTrademark("")]
[assembly: AssemblyCulture("")]

namespace StickyNotes
{
    public class Handler : IHttpHandler
    {
        public void ProcessRequest(HttpContext context)
        {
            if(context.IsWebSocketRequest)
            {
                context.AcceptWebSocketRequest(new StickyHandler().Receive);
            }
        }
        
        public bool IsReusable
        {
            get
            {
                return false;
            }
        }
    }
    
    public class StickyHandler
    {
        private static List<StickyHandler> connectedHandlers = new List<StickyHandler>();
        private WebSocket socket;
        
        public async Task Receive(AspNetWebSocketContext context)
        {
            var log = new LogUtil(context.Server.MapPath("~"), context.UserHostAddress);
            connectedHandlers.Add(this);
            try
            {
                log.Info("Connect UserAgent:" + context.UserAgent + " UserHostAddress" + context.UserHostAddress + " UserHostName:" + context.UserHostName);
                socket = context.WebSocket;
                var buffer = new ArraySegment<byte>(new byte[65536]);
                while(true)
                {
                    WebSocketReceiveResult result = null;
                    var allBytes = new List<byte>();
                    do
                    {
                        result = await socket.ReceiveAsync(buffer, CancellationToken.None);
                        for(var i = 0; i <result.Count; i++)
                        {
                            allBytes.Add(buffer.Array[i]);
                        }
                    }
                    while(!result.EndOfMessage);
                    if(result.MessageType == WebSocketMessageType.Close)
                    {
                        log.Info("Disconnect UserAgent:" + context.UserAgent + " UserHostAddress" + context.UserHostAddress + " UserHostName:" + context.UserHostName);
                        await socket.CloseOutputAsync(WebSocketCloseStatus.NormalClosure, string.Empty, CancellationToken.None);
                        break;
                    }
                    else if(result.MessageType == WebSocketMessageType.Text)
                    {
                        var storage = new StickyStorage(context.Server.MapPath("~"));
                        if(result.Count > 0)
                        {
                            var json = JObject.Parse(Encoding.UTF8.GetString(allBytes.ToArray(), 0, allBytes.Count));
                            var note = JsonConvert.DeserializeObject<Note>(json.ToString());
                            if(note.No == 0)
                            {
                                storage.Insert(note, context.UserHostAddress);
                            }
                            else
                            {
                                storage.Update(note, context.UserHostAddress);
                            }
                        }
                        this.Broadcast(JsonConvert.SerializeObject(storage.Select(), Formatting.None));
                    }
                }
            }
            catch(Exception ex)
            {
                log.Error(ex.Message);
                log.Error(ex.StackTrace);
                throw;
            }
            finally
            {
                connectedHandlers.Remove(this);
            }
        }
        
        private void Broadcast(string message)
        {
            foreach(var handler in connectedHandlers)
            {
                var buffer = new ArraySegment<byte>(Encoding.UTF8.GetBytes(message));
                handler.socket.SendAsync(buffer, WebSocketMessageType.Text, true, CancellationToken.None);
            }
        }
    }
    
    public class StickyStorage
    {
        private string connectionString;
        
        public StickyStorage(string path)
        {
            this.connectionString = new SQLiteConnectionStringBuilder { DataSource = path + "/db.sqlite" }.ToString();
            using(var connection = new SQLiteConnection(this.connectionString))
            {
                connection.Open();
                using(var command = new SQLiteCommand(connection))
                {
                    command.CommandText = "CREATE TABLE IF NOT EXISTS T_NOTES(" +
                                          "  NO       INTEGER   NOT NULL PRIMARY KEY AUTOINCREMENT," +
                                          "  MESSAGE  TEXT      ," +
                                          "  URL      TEXT      ," +
                                          "  COLOR    TEXT      NOT NULL," +
                                          "  POSITION TEXT      NOT NULL," +
                                          "  TOP      TEXT      NOT NULL," +
                                          "  LEFT     TEXT      NOT NULL," +
                                          "  WIDTH    TEXT      NOT NULL," +
                                          "  HEIGHT   TEXT      NOT NULL," +
                                          "  IP       TEXT      NOT NULL," +
                                          "  TS       TIMESTAMP NOT NULL DEFAULT (DATETIME('now', 'localtime'))," +
                                          "  DELFLG   INTEGER   NOT NULL DEFAULT 0)";
                    command.ExecuteNonQuery();
                }
            }
        }
        
        public void Insert(Note note, string ip)
        {
            using(var connection = new SQLiteConnection(this.connectionString))
            {
                connection.Open();
                using(var command = new SQLiteCommand(connection))
                {
                    command.CommandText = "INSERT INTO T_NOTES (MESSAGE, URL, COLOR, POSITION, TOP, LEFT, WIDTH, HEIGHT, IP) VALUES (@MESSAGE, @URL, @COLOR, @POSITION, @TOP, @LEFT, @WIDTH, @HEIGHT, @IP)";
                    command.Parameters.Add(new SQLiteParameter("@MESSAGE", note.Message));
                    command.Parameters.Add(new SQLiteParameter("@URL", note.Url));
                    command.Parameters.Add(new SQLiteParameter("@COLOR", note.Color));
                    command.Parameters.Add(new SQLiteParameter("@POSITION", note.Position));
                    command.Parameters.Add(new SQLiteParameter("@TOP", note.Top));
                    command.Parameters.Add(new SQLiteParameter("@LEFT", note.Left));
                    command.Parameters.Add(new SQLiteParameter("@WIDTH", note.Width));
                    command.Parameters.Add(new SQLiteParameter("@HEIGHT", note.Height));
                    command.Parameters.Add(new SQLiteParameter("@IP", ip));
                    command.ExecuteNonQuery();
                }
            }
        }
        
        public void Update(Note note, string ip)
        {
            using(var connection = new SQLiteConnection(this.connectionString))
            {
                connection.Open();
                using(var command = new SQLiteCommand(connection))
                {
                    command.CommandText = "UPDATE T_NOTES SET MESSAGE=@MESSAGE, URL=@URL, COLOR=@COLOR, POSITION=@POSITION, TOP=@TOP, LEFT=@LEFT, WIDTH=@WIDTH, HEIGHT=@HEIGHT, IP=@IP, TS=DATETIME('now', 'localtime'), DELFLG=@DELFLG WHERE NO=@NO";
                    command.Parameters.Add(new SQLiteParameter("@MESSAGE", note.Message));
                    command.Parameters.Add(new SQLiteParameter("@URL", note.Url));
                    command.Parameters.Add(new SQLiteParameter("@COLOR", note.Color));
                    command.Parameters.Add(new SQLiteParameter("@POSITION", note.Position));
                    command.Parameters.Add(new SQLiteParameter("@TOP", note.Top));
                    command.Parameters.Add(new SQLiteParameter("@LEFT", note.Left));
                    command.Parameters.Add(new SQLiteParameter("@WIDTH", note.Width));
                    command.Parameters.Add(new SQLiteParameter("@HEIGHT", note.Height));
                    command.Parameters.Add(new SQLiteParameter("@IP", ip));
                    command.Parameters.Add(new SQLiteParameter("@DELFLG", note.Delete));
                    command.Parameters.Add(new SQLiteParameter("@NO", note.No));
                    command.ExecuteNonQuery();
                }
            }
        }
        
        public List<Note> Select()
        {
            var notes = new List<Note>();
            using(var connection = new SQLiteConnection(this.connectionString))
            {
                connection.Open();
                using(var command = new SQLiteCommand(connection))
                {
                    command.CommandText = "SELECT * FROM T_NOTES WHERE DELFLG=0 ORDER BY NO";
                    using(var reader = command.ExecuteReader())
                    {
                        while(reader.Read())
                        {
                            var note = new Note();
                            note.Message = reader["MESSAGE"].ToString();
                            note.Url = reader["URL"].ToString();
                            note.No = int.Parse(reader["No"].ToString());
                            note.Color = reader["COLOR"].ToString();
                            note.Position = reader["POSITION"].ToString();
                            note.Top = reader["TOP"].ToString();
                            note.Left = reader["LEFT"].ToString();
                            note.Width = reader["WIDTH"].ToString();
                            note.Height = reader["HEIGHT"].ToString();
                            note.Timestamp = reader["TS"].ToString();
                            note.Delete = int.Parse(reader["DELFLG"].ToString());
                            notes.Add(note);
                        }
                    }
                }
            }
            return notes;
        }
    }
    
    public class LogUtil
    {
        private string logFile = "";
        private string address = "";
        
        public LogUtil(string path, string address)
        {
            var directory = path + "/log";
            Directory.CreateDirectory(directory);
            this.logFile = directory + "/log_" + DateTime.Now.ToString("yyyyMMdd") + ".txt";
            this.address = address;
        }
        
        public void Info(string message)
        {
            this.Output(string.Format("{0} INFO [{1}] {2}", DateTime.Now.ToString(), this.address, message));
        }
        
        public void Error(string message)
        {
            this.Output(string.Format("{0} ERROR [{1}] {2}", DateTime.Now.ToString(), this.address, message));
        }
        
        private void Output(string message)
        {
            using(var sw = new StreamWriter(this.logFile, true, Encoding.UTF8))
            {
                sw.WriteLine(message);
            }
        }
    }
    
    [JsonObject]
    public class Note
    {
        [JsonProperty("message")]
        public string Message { get; set; }
        
        [JsonProperty("url")]
        public string Url { get; set; }
        
        [JsonProperty("no")]
        public int No { get; set; }
        
        [JsonProperty("color")]
        public string Color { get; set; }
        
        [JsonProperty("position")]
        public string Position { get; set; }
        
        [JsonProperty("top")]
        public string Top { get; set; }
        
        [JsonProperty("left")]
        public string Left { get; set; }
        
        [JsonProperty("width")]
        public string Width { get; set; }
        
        [JsonProperty("height")]
        public string Height { get; set; }
        
        [JsonProperty("timestamp")]
        public string Timestamp { get; set; }
        
        [JsonProperty("delete")]
        public int Delete { get; set; }
    }
}
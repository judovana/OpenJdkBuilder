
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;

/**
 *
 * @author jvanek
 */
public class CheckBugs {

    private static final String DEFAULT_USER = "AssigneeNotSet";
    private static final boolean HTML = true;

    private static int hgIncommingNegativeCounter = 0;
    private static int hgIncommingCounter = 0;
    private static int hgIncommingPositiveCounter = 0;
    private static int foundBugsCounter = 0;
    private static int notFoundCounter = 0;
    private static int allBugsCounter = 0;
    private static int allBugsCounter2 = 0;
    private static int foundBugsCounter2 = 0;

    /**
     * @param args the command line arguments
     */
    public static void main(String[] args) throws IOException, InterruptedException {
//        String testPath = "/home/jvanek/Desktop/";
//        args = new String[]{testPath + "CPU", testPath + "yyy/hgIncoming.log"};
//        args = new String[]{testPath + "/CPU",
//            testPath + "yyy/jdk-hg.log",
//            testPath + "yyy/hotspot-hg.log",
//            testPath + "yyy/nashorn-hg.log",
//            testPath + "yyy/jaxws-hg.log",
//            testPath + "yyy/jaxp-hg.log",
//            testPath + "yyy/corba-hg.log",
//            testPath + "yyy/langtools-hg.log",
//            testPath + "yyy/java-1.8.0-openjdk-dev-hg.log"
//        };
        if (args.length < 2) {
            System.out.println("expected two and more params. First is file with bugs, second (any other) are files to scan for logs");
            System.out.println(" if only one log is give (== two params) then  search of \"what bugs are those changsets related to?\"");
            System.out.println("  - so listed are changeset,  green for bugged one, red for non bugged one");
            System.out.println(" if  more logs to search are given (3+ params) then all bugs are processed, with inforamtion \"green, found in thsi changeset, red, not found at all\"");
            System.out.println("hg log is expected normal, ornormal with description on top of it. See template in this directory");
            System.out.println("changeset:   3341:b4e8c36b4c34");
            System.out.println("optional parent:   12196:072df97b6e2a");
            System.out.println("tag:         tip");
            System.out.println("user:        asaha");
            System.out.println("date:        Mon Mar 27 08:22:58 2017 -0700");
            System.out.println("summary:     Added tag jdk8u152-b02 for changeset a283fc8f44ac");
            System.out.println("description:  line1");
            System.out.println("description:  lineN");
            System.out.println("everything wihtout one of those 5 prefixes is ignored");
            System.out.println("First line of description is ommited from analyse, as itis actually the summary");
            System.out.println("file with bugs is ");
            System.out.println("user1  bugnumber1 bugnumber2 .. bugnumbern");
            System.out.println("user2  bugnumber1 bugnumber2 .. bugnumbern");
            System.out.println("separator is any non-alphanumeric char");
            System.out.println("newline is automatically resting assignee");
            System.out.println("line sstarting with # are skipped");
            System.out.println("bugs witout assignee goes to unassigned user (if any).. can all..");
            System.exit(1);
        }
        BugList bugList = new BugList(new File(args[0]));
        bugList.read();
        System.err.println("from " + args[0] + " read " + bugList.allBugs.size() + " bugs for " + bugList.userBugs.size() + " users");
        List<HgLog> logs = new ArrayList<>();
        for (int i = 1; i < args.length; i++) {
            HgLog hgLog = new HgLog(new File(args[i]));
            hgLog.read();
            logs.add(hgLog);
            System.err.println("From " + args[i] + " read " + hgLog.getRecords().size() + " chnagesets");

        }
        System.err.flush();
        Thread.sleep(1000);
        System.out.flush();
        Thread.sleep(1000);
        System.err.flush();
        if (logs.size() == 1) {
            List<ChangesetsWithBugs> all = logs.get(0).getChangesetsForBugs(bugList);
            //first sort by bugid, so it is grupped later
            Collections.sort(all, new Comparator<ChangesetsWithBugs>() {

                @Override
                public int compare(ChangesetsWithBugs o1, ChangesetsWithBugs o2) {
                    //empty lists first
                    if (o1.record.possibleBugs.size() > 0
                            && o2.record.possibleBugs.size() > 0) {
                        return o1.record.possibleBugs.get(0).compareTo(o2.record.possibleBugs.get(0));
                    }
                    return o1.record.possibleBugs.size() - o2.record.possibleBugs.size();
                }
            });
            //then by fixed/not fixed
            Collections.sort(all, new Comparator<ChangesetsWithBugs>() {

                @Override
                public int compare(ChangesetsWithBugs o1, ChangesetsWithBugs o2) {
                    //empty lists first
                    return o1.found.size() - o2.found.size();
                }
            });
            for (ChangesetsWithBugs set : all) {
                for (Integer bug : set.record.possibleBugs) {
                    for (HgLogRecord record : logs.get(0).getRecords()) {
                        if (record.isMentionedHere(bug)) {
                            set.mentioned.add(record);
                        }
                    }
                }
            }
            if (HTML) {
                System.out.println("<html><body>");
                System.out.println("<p>");
            }
            System.out.println(titleL1(args[0]));
            System.out.println(titleL2(args[1]));
            System.out.println("Chagesets coresponds to loaded bugs:");
            if (HTML) {
                System.out.println("</p>");
            }

            for (ChangesetsWithBugs a : all) {
                System.out.print(a.toString(bugList, GoodBugs.from2(all)));
            }
            if (HTML) {
                System.out.println("</body></html>");
            }
        } else {
            //print out in red what bugs are still not there
            //print green bugs which are there, maybe with some more info?
            List<BugWithRecords> bugsWithRecords = new ArrayList<>(bugList.allBugs.size());
            List<BugWithUser> otherBugs = new ArrayList<>(bugList.allBugs.size());
            for (Integer i : bugList.allBugs) {
                List<HgLogRecord> rs = new ArrayList<>(1);
                for (HgLog log : logs) {
                    rs.addAll(log.getAllRecordsForThisBug(i));
                }
                if (rs.size() > 0) {
                    bugsWithRecords.add(new BugWithRecords(i, rs));
                } else {
                    otherBugs.add(new BugWithUser(i, bugList.bugsUSers.get(i)));
                }

            }
            for (HgLog log : logs) {
                for (HgLogRecord record : log.getRecords()) {
                    for (Mentioned output : otherBugs) {
                        if (record.possibleSecndaryBugs.contains(output.getBug())) {
                            output.mentionedIn(record);
                        }
                    }
                    for (Mentioned output : bugsWithRecords) {
                        if (record.possibleSecndaryBugs.contains(output.getBug())) {
                            output.mentionedIn(record);
                        }
                    }
                }
            }
            Collections.sort(otherBugs, new Comparator<BugWithUser>() {

                @Override
                public int compare(BugWithUser o1, BugWithUser o2) {
                    return o1.user.compareTo(o2.user);
                }

            });
            Collections.sort(bugsWithRecords, new Comparator<BugWithRecords>() {

                @Override
                public int compare(BugWithRecords o1, BugWithRecords o2) {
                    //empty lists first
                    return o1.records.size() - o2.records.size();
                }
            });
            if (HTML) {
                System.out.println("<html><body>");
                System.out.println("<p>");
            }
            System.out.println(titleL1(args[0]));
            System.out.println(titleL3(args));
            System.out.println("Bugs are/are not found:");
            if (HTML) {
                System.out.println("</p>");
            }
            if (HTML) {
                System.out.println("<font color='red'>\n");
            }
            System.out.println("<h3>Bugs not yet fixed:</h3>");
            for (BugWithUser i : otherBugs) {
                notFoundCounter++;
                allBugsCounter++;
                allBugsCounter2++;
                System.out.println(notFoundCounter + "|" + allBugsCounter + ") " + i.printHeader(null));
                if (HTML) {
                    System.out.println("<br/>");
                }
                if (!i.secondaryMentions.isEmpty()) {
                    System.out.println(i.printMentions(GoodBugs.from1(bugsWithRecords)));
                    if (HTML) {
                        System.out.println("<br/>");
                    }
                }
            }
            if (HTML) {
                System.out.println("</font>");
            }
            if (HTML) {
                System.out.println("<font color='green'>\n");
            }
            System.out.println("");
            System.out.println("<h3>Bugs appearing in logs:</h3>");
            for (BugWithRecords br : bugsWithRecords) {
                System.out.print(br.toString(bugList, GoodBugs.from1(bugsWithRecords)));
            }

            if (HTML) {
                System.out.println("</font>");
            }
            if (HTML) {
                System.out.println("</body></html>");
            }
        }

    }

    private static String titleL1(String bugsFile) {
        return "Based on bug IDs in : " + href(bugsFile);
    }

    private static String titleL3(String... logs) {
        StringBuilder sb = new StringBuilder();
        sb.append("and information in  : ");
        for (int i = 1; i < logs.length; i++) {
            String log = logs[i];
            sb.append(href(log)).append("; ");
        }
        return sb.toString();
    }

    private static String titleL2(String incomingLog) {
        return "(underlined are duplicates) and information in  : " + href(incomingLog);
    }

    private static String href(String bugsFile) {
        if (HTML) {
            return "<a href='" + bugsFile + "'>" + new File(bugsFile).getName() + "</a>";
        } else {
            return bugsFile;
        }
    }

    private static class HgLog {

        private final File backend;
        private final List<HgLogRecord> records = new ArrayList<>();
        private String currentRepo;

        private HgLog(File file) {
            this.backend = file;
            currentRepo = file.getName();
        }

        public List<HgLogRecord> getRecords() {
            return records;
        }

        public String getMercurialLineContent(String s) {
            return s.replaceAll(".*   ", "");
        }

        public void read() throws IOException {
            try (BufferedReader br = new BufferedReader(new InputStreamReader(new FileInputStream(backend), "UTF-8"))) {
                HgLogRecord current = new HgLogRecord("not:initializsed", currentRepo);
                while (true) {
                    String line = br.readLine();
                    if (line == null) {
                        break;
                    }
                    if (line.startsWith("changeset:")) {
                        current = new HgLogRecord(getMercurialLineContent(line), currentRepo);
                        records.add(current);
                    } else if (line.startsWith("parent:")) {
                        current.addParent(getMercurialLineContent(line));
                    } else if (line.startsWith("tag:")) {
                        current.addTag(getMercurialLineContent(line));
                    } else if (line.startsWith("user:")) {
                        current.setUser(getMercurialLineContent(line));
                    } else if (line.startsWith("date:")) {
                        current.setDate(getMercurialLineContent(line));
                    } else if (line.startsWith("summary:")) {
                        current.setSummary(getMercurialLineContent(line));
                    } else if (line.startsWith("description:")) {
                        current.addDescription(getMercurialLineContent(line));
                    } else if (!line.trim().isEmpty()) {
                        if (line.startsWith("comparing with ")) {
                            currentRepo = line.substring(line.lastIndexOf("/"));
                        } else {
                            System.err.println("Unknown line of: " + line);
                        }
                    }
                }

            }
        }

        private List<ChangesetsWithBugs> getChangesetsForBugs(BugList bugList) {
            List<ChangesetsWithBugs> all = new ArrayList<>(records.size());

            for (HgLogRecord record : records) {
                List<Integer> found = record.getKnownBugs(bugList);
                all.add(new ChangesetsWithBugs(record, found, backend.getName()));
            }
            return all;
        }

        private List<HgLogRecord> getAllRecordsForThisBug(Integer i) {
            List<HgLogRecord> r = new ArrayList<>(1);
            for (HgLogRecord record : records) {
                if (record.possibleBugs.contains(i)) {
                    record.setLog(this);
                    r.add(record);
                }
            }
            return r;
        }
    }

    private static class HgLogRecord {

        private final List<Integer> possibleBugs = new ArrayList<>();
        private List<Integer> possibleSecndaryBugs = new ArrayList<>();
        private final String changeset;
        private final String repo;
        private String user;
        private String date;
        private String summary;
        private final List<String> description = new ArrayList<>();
        private final List<String> parents = new ArrayList<>();
        private final List<String> tags = new ArrayList<>();
        //to save search, save link to parent in second type ofusage
        private HgLog log;

        public boolean setDate(String d) {
            if (date == null) {
                this.date = d;
                return true;
            } else {
                System.err.println("Not overwriteing date of " + date + " by " + d);
                return false;
            }
        }

        /*
you need to handle multi-line
commit comments, as this one:

8167110: Windows peering issue
7155957: closed/java/awt/MenuBar/MenuBarStress1/MenuBarStress1.java
hangs on win 64 bit with jdk8
8079595: Resizing dialog which is JWindow parent makes JVM crash
8147842: IME Composition Window is displayed at incorrect location
Reviewed-by: serb

Same for 8190789, at changeset 43342bcc1348.
        
        This needs hg log -v ; which lead to description: instead  of sumamry :( and have many files list and so on.
        Summary looks to be the first line of description

Summary is in format
summary: line
Description is in format
description:
lines
         */
        public void addDescription(String s) {
            this.description.add(s);
            possibleSecndaryBugs = new ArrayList<>();
            //ignore first line as itis always also in summary
            for (int i = 1; i < description.size(); i++) {
                String get = description.get(i);
                possibleSecndaryBugs.addAll(getBugsImpl(get));
            }
        }

        public boolean setSummary(String s) {
            if (summary == null) {
                this.summary = s;
                getBugs();
                return true;
            } else {
                System.err.println("Not overwriteing summary of " + summary + " by " + s);
                return false;
            }
        }

        public void addTag(String s) {
            tags.add(s);
            if (tags.size() > 1) {
                //System.err.println(changeset + " more then one tag - " + tags.size());
            }
        }

        public boolean setUser(String u) {
            if (user == null) {
                this.user = u;
                return true;
            } else {
                System.err.println("Not overwriteing user of " + user + " by " + u);
                return false;
            }
        }

        public void addParent(String s) {
            parents.add(s);
            if (parents.size() > 1) {
                //System.err.println(changeset + " more then one parent - " + parents.size());
            }
        }

        public HgLogRecord(String changeset, String repo) {
            this.changeset = changeset;
            this.repo = repo;
        }

        private void getBugs() {
            possibleBugs.addAll(getBugsImpl(summary));
        }

        private List<Integer> getKnownBugs(BugList bugList) {
            List<Integer> r = new ArrayList<>(1);
            for (Integer possibleBug : possibleBugs) {
                if (bugList.bugs.contains(possibleBug)) {
                    r.add(possibleBug);
                }
            }
            return r;
        }

        private boolean isMentionedHere(Integer bug) {
            return possibleSecndaryBugs.contains(bug);
        }

        private void setLog(HgLog a) {
            this.log = a;
        }
    }

    private static class BugList {

        private final File backend;
        //using trer map to keep users sorted
        private final Map<String, List<Integer>> userBugs = new TreeMap<>();
        private final List<Integer> allBugs = new ArrayList<>();
        private final Set<Integer> bugs = new TreeSet<>();
        private final Map<Integer, String> bugsUSers = new TreeMap<>();

        private BugList(File file) {
            this.backend = file;
        }

        public void read() throws IOException {
            String lastUser = DEFAULT_USER;
            try (BufferedReader br = new BufferedReader(new InputStreamReader(new FileInputStream(backend), "UTF-8"))) {
                while (true) {
                    String line = br.readLine();
                    if (line == null) {
                        break;
                    }
                    line = line.trim();
                    //comments
                    if (line.startsWith("#")) {
                        lastUser = DEFAULT_USER;
                        continue;
                    }
                    String[] words = splitNonAlphaNUmeric(line);
                    for (String w : words) {
                        try {
                            Integer bug = Integer.valueOf(w);
                            put(lastUser, bug);
                        } catch (NumberFormatException ex) {
                            lastUser = w;
                        }
                    }
                    //new line reset to default user
                    lastUser = DEFAULT_USER;
                }
            }
        }

        private void put(String lastUser, Integer bug) {
            List<Integer> users = userBugs.get(lastUser);
            if (users == null) {
                users = new ArrayList<>();
                userBugs.put(lastUser, users);
            }
            users.add(bug);
            bugs.add(bug);
            allBugs.add(bug);
            bugsUSers.put(bug, lastUser);

        }

    }

    private static String[] splitNonAlphaNUmeric(String line) {
        return line.split("[^\\w']+");

    }

    private static Integer lastBug = null;

    private static class ChangesetsWithBugs {

        private final HgLogRecord record;
        private final List<Integer> found;
        private final List<HgLogRecord> mentioned = new ArrayList<>(1);
        private final String name;

        private ChangesetsWithBugs(HgLogRecord record, List<Integer> found, String name) {
            this.record = record;
            this.found = found;
            this.name = name;
        }

        public String toString(BugList bl, GoodBugs good) {
            StringBuilder sb = new StringBuilder();
            boolean isTag = false;
            if (record.summary.trim().startsWith("Added tag")) {
                isTag = true;
                if (HTML) {
                    sb.append("<div style='font-size:75%'>");
                }
            }
            if (HTML) {
                sb.append("<p>");
                if (found.isEmpty()) {
                    sb.append("<font color='red'>\n");
                } else {
                    sb.append("<font color='green'>\n");
                }
            }
            int usedCounter = 0;
            if (found.isEmpty()) {
                hgIncommingNegativeCounter++;
                usedCounter = hgIncommingNegativeCounter;
            } else {
                hgIncommingPositiveCounter++;
                usedCounter = hgIncommingPositiveCounter;
            }
            hgIncommingCounter++;
            if (lastBug != null && this.record.possibleBugs.size() > 0) {
                if (lastBug.equals(this.record.possibleBugs.get(0))) {
                    strike(sb);
                }
            }
            sb.append(usedCounter + "/" + hgIncommingCounter + ") " + record.summary + " (" + record.repo + ")");
            if (lastBug != null && this.record.possibleBugs.size() > 0) {
                if (lastBug.equals(this.record.possibleBugs.get(0))) {
                    unstrike(sb);
                }
            }
            newLine(sb, isTag);
            sb.append(mentionedToStr(this.mentioned, "- ", good));
            if (!mentioned.isEmpty()) {
                newLine(sb);
            }
            if (found.isEmpty()) {
                sb.append(" - this chnageset do not have any known bug");
                newLine(sb, isTag);
            } else {
                sb.append(" - this changeset have corresponding bug");
                newLine(sb, isTag);
                if (HTML) {
                    sb.append("<b>");
                }
                for (Integer bug : found) {
                    sb.append(" - " + bug + " " + bl.bugsUSers.get(bug));
                    newLine(sb, isTag);
                }
                if (HTML) {
                    sb.append("</b>");
                }
            }
            if (HTML) {
                sb.append("<small>\n");
            }
            sb.append(" - - " + record.changeset + "; parents:(");
            for (String s : record.parents) {
                sb.append(" " + s);
            }
            sb.append(" )");
            newLine(sb, isTag);
            sb.append(" - - " + record.date + "; tags:(");
            for (String s : record.tags) {
                sb.append(" " + s);
            }
            sb.append(" )");
            newLine(sb, isTag);
            sb.append(" - - " + record.user);
            //new line anytime
            newLine(sb);
            if (HTML) {
                sb.append("</small>\n");
            }
            if (HTML) {
                sb.append("</font>");
                sb.append("</p>\n");
            }
            if (HTML && isTag) {
                sb.append("</div>");
            }
            lastBug = null;
            if (this.record.possibleBugs.size() > 0) {
                lastBug = this.record.possibleBugs.get(0);
            }
            return sb.toString();
        }

        private void strike(StringBuilder sb) {
            if (HTML) {
                sb.append("<u>");
            } else {
                sb.append("/\\/\\/");
            }
        }

        private void unstrike(StringBuilder sb) {
            if (HTML) {
                sb.append("</u>");
            } else {
                sb.append("/\\/\\/");
            }
        }

    }

    private static void newLine(StringBuilder sb) {
        newLine(sb, false);
    }

    private static void newLine(StringBuilder sb, boolean isTag) {
        if (isTag) {
            sb.append(" | ");
        } else {
            if (HTML) {
                sb.append("<br/>");
            }
            sb.append("\n");

        }
    }

    private static class BugWithRecords implements Mentioned {

        private final Integer bug;
        private final List<HgLogRecord> records;
        private final List<HgLogRecord> secondaryMentions = new ArrayList<>(1);

        private BugWithRecords(Integer i, List<HgLogRecord> record) {
            this.bug = i;
            this.records = record;
        }

        public String toString(BugList bl, GoodBugs goodBugs) {
            StringBuilder sb = new StringBuilder();
            if (HTML) {
                sb.append("<p>");

            }
            if (HTML) {
                sb.append("<b>");
            }
            foundBugsCounter++;
            allBugsCounter++;
            sb.append(foundBugsCounter + "|" + allBugsCounter + ") " + printHeader(bl));
            newLine(sb);
            if (HTML) {
                sb.append("</b>");
            }
            if (!this.secondaryMentions.isEmpty()) {
                if (HTML) {
                    sb.append("<br/>");
                }
                sb.append(this.printMentions(goodBugs));
            }
            for (HgLogRecord record : records) {
                if (HTML) {
                    sb.append("<blockquote>");

                }
                foundBugsCounter2++;
                allBugsCounter2++;
                sb.append(foundBugsCounter2 + "|" + allBugsCounter2 + ") " + record.summary + " (" + record.log.backend.getName() + ")");
                newLine(sb);
                if (HTML) {
                    sb.append("<small>\n");
                }
                sb.append(" - - " + record.changeset + "; parents:(");
                for (String s : record.parents) {
                    sb.append(" " + s);
                }
                sb.append(" )");
                newLine(sb);
                sb.append(" - - " + record.date + "; tags:(");
                for (String s : record.tags) {
                    sb.append(" " + s);
                }
                sb.append(" )");
                newLine(sb);
                sb.append(" - - " + record.user);
                newLine(sb);
                if (HTML) {
                    sb.append("</small>\n");
                }
                if (HTML) {
                    sb.append("</blockquote>\n");
                }
            }
            if (HTML) {
                sb.append("</p>");

            }
            return sb.toString();
        }

        @Override
        public void mentionedIn(HgLogRecord record) {
            secondaryMentions.add(record);
        }

        @Override
        public int getBug() {
            return bug;
        }

        @Override
        public String printHeader(BugList bl) {
            return bug + " - " + bl.bugsUSers.get(bug);
        }

        @Override
        public String printMentions(GoodBugs good) {
            return mentionedToStr(secondaryMentions, "_____ ", good);
        }

    }

    private static class BugWithUser implements Mentioned {

        private final Integer bug;
        private final String user;
        private final List<HgLogRecord> secondaryMentions = new ArrayList<>(1);

        public BugWithUser(Integer i, String user) {
            this.bug = i;
            this.user = user;

        }

        @Override
        public String printHeader(BugList bl) {
            return bug + " - " + user;
        }

        @Override
        public String printMentions(GoodBugs good) {
            return mentionedToStr(secondaryMentions, "_____ ", good);
        }

        @Override
        public void mentionedIn(HgLogRecord record) {
            secondaryMentions.add(record);
        }

        @Override
        public int getBug() {
            return bug;
        }

    }

    private static String mentionedToStr(List<HgLogRecord> secondaryMentions, String indent, GoodBugs goodBugs) {
        if (secondaryMentions.isEmpty()) {
            return "";
        }
        String s = "";
        if (HTML) {
            s = s + "<small><font color='lightblue'>";
        }
        s = s + indent + "Mentioned also in:";
        for (HgLogRecord secondaryMention : secondaryMentions) {
            String color;
            if (goodBugs.contains(secondaryMention.summary)) {
                color = "lightgreen";
            } else {
                color = "pink";
            }
            s = s + "<font color='" + color + "'>" + secondaryMention.summary + " (" + secondaryMention.repo + ")" + ";</font >";
        }
        if (HTML) {
            s = s + "</font></small>";
        }
        return s;
    }

    private static interface Mentioned {

        String printHeader(BugList bl);

        String printMentions(GoodBugs good);

        void mentionedIn(HgLogRecord record);

        int getBug();

    }

    private static List<Integer> getBugsImpl(String s) {
        final List<Integer> possibleBugs = new ArrayList<>();
        String[] words = splitNonAlphaNUmeric(s);
        for (String w : words) {
            //bugs for jdk 6,7,8,9 are always Xzzzzzz where X is 6,7,8,9:)
            // so 7 digits for those jdk. Hard to say what jdk10 will look like
            if (w.length() == 7 || w.length() == 8) {
                try {
                    Integer bug = Integer.valueOf(w);
                    possibleBugs.add(bug);
                } catch (NumberFormatException ex) {

                }
            }
        }
        return possibleBugs;
    }

    private static class GoodBugs {

        private static GoodBugs from1(List<BugWithRecords> bugsWithRecords) {
            GoodBugs gb = new GoodBugs();
            for (BugWithRecords set : bugsWithRecords) {
                gb.goodBugs.add(set.bug);
            }
            return gb;
        }

        private static GoodBugs from2(List<ChangesetsWithBugs> all) {
            GoodBugs gb = new GoodBugs();
            for (ChangesetsWithBugs set : all) {
                if (set.found.size() > 0) {
                    gb.goodBugs.addAll(set.record.possibleBugs);
                }
            }
            return gb;
        }

        List<Integer> goodBugs = new ArrayList<>();

        private boolean contains(String summary) {
            List<Integer> bugs = getBugsImpl(summary);
            for (Integer bug : bugs) {
                if (goodBugs.contains(bug)) {
                    return true;
                }
            }
            return false;
        }
    }

}

%{
    Updated 25.10.2018
    Change in API section the (log file name) and (log file path)
    other values in API Only for printing purpose, does not affect the calculations
%}

% clear
% close all
% clc

%% **API**************%
expName = 'node07_BCH_50_withsensilla.log';           % keyword from the experiment name and does not need to be exact full name
% expName = 'node07_BL_50_30_3_3.log';   
direct = 'C:\Users\zeynep\Documents\MATLAB\Draise_paper\';         % searching in the cloud logs path

%Only for printing purpose, does not affect the calculations
Rate = 2;
randomNum = 3;
Push = 5;

%% Validating file name ********%
[logsFile, errmsg] = fopen([direct expName],'r');
if logsFile<0 
    disp(errmsg);
    return;
else
    line = fgets(logsFile);
	LineNum = 1;
end

%% Definitions *****%
IPtable = ["fd00::1b50:5933:3043:d239", "fd00::736:3239:314d:d733", "fd00::1b51:5033:3043:d639", "fd00::742:3139:314d:d733", "fd00::2345:5933:3043:d639", "fd00::2342:6533:3043:d939", "fd00::1b51:4933:3043:d639", "fd00::1b51:6333:3043:d439", "fd00::2344:6233:3043:d639", "fd00::2344:6333:3043:d439"];
IPtable = [IPtable; "Node 24", "Node 19", "Node 15", "Node 7", "Node 13", "Node 25", "Node 17", "Node 10", "Node 4", "Node 23"];


% IPtable = ["AAAA:0:0:0:536:3239:314D:D733", "AAAA:0:0:0:1951:4933:3043:D639", "AAAA:0:0:0:1962:5133:3043:D739", "AAAA:0:0:0:1951:6333:3043:D439 ", "AAAA:0:0:0:2144:6333:3043:D439"];
% IPtable = [IPtable; "Node 23", "Node 25", "Node 13", "Node 24", "Node 10"];


root.rf_channel_number = 0;
root.IP = [];
root.nodesIP = [];
root.Packet_counter = 0;
root.init = [0 0];

node.number = [];
node.IP = [];
node.PRRlogs = [];
node.RSSI = [];
node.hops = [];
node.onehopRSSI = [];
node.Timestamp = [];
node.PRRlogs = [];
node.count = [];
node.PRRhrs = {};
node.TS_overflow = 0;
node.count_offset = 0;

TS_Overflow = 2^18;
% linenum=0
%% Getting data
fprintf("Collecting the data from the log file...\n");
while ischar(line)
%     linenum=linenum+1;
    if length(line)>5
      
        % root init function %
        if sum(root.init) ~= 2
            if contains(line,'Serial port ')
                root.rf_channel_number = str2num(getFromTo(line, "Serial port ", newline)); %#ok<ST2NM>
                root.init(1) = 1;
            end
            if line(1:3) == "New"
                root.IP = getFromTo(line, "New Worker", newline);
                root.init(2) = 1;
            end
        end
        
        %Getting nodes results %
        if line(1:5) == "[Entr"
            root.Packet_counter = root.Packet_counter +1;
            IP = extractBetween(line,"Address ","] [Hops");
%             if iscellstr(IP) == 0
%                display(line);
%                continue;
%             end
            flag = 0;
            
            if length(root.nodesIP) >= 1
                for i = 1:length(root.nodesIP)
                    if (strcmp(IP,root.nodesIP(i)))
                        index = i;
                        flag =1;
                    end
                end
                if flag == 0
                    root.nodesIP = [root.nodesIP ; IP];
                    index = length(root.nodesIP);
                    node(index).TS_overflow = 0;
                    node(index).count_offset = 0;
                end
            else
                root.nodesIP = [root.nodesIP ; IP];
                index = 1;
            end
            
            node(index).IP = IP; %#ok<SAGROW>
%             display(linenum)
            xx = strfind(IPtable, IP);
            x = find(not(cellfun('isempty',xx)))+1;
            if isempty(x)
                node(index).number = string(IP);
            else
                node(index).number = IPtable(x); %#ok<SAGROW>
            end

            TS_H_ED_count_PRR = [getParam(line,"Hops "), getParam(line,"Count "), getParam(line,"PRR ~"), getParam(line,"RSSI ")];
            if any(find(TS_H_ED_count_PRR == -1))
                fprintf("In Line: %d\n",LineNum);
                line = fgets(logsFile);
                LineNum = LineNum +1;
                continue;
            end
            node(index).Timestamp     = [node(index).Timestamp (TS_Overflow*node(index).TS_overflow)+ TS_H_ED_count_PRR(1)];
            node(index).hops          = [node(index).hops TS_H_ED_count_PRR(1)];
            node(index).count         = [node(index).count TS_H_ED_count_PRR(2)];
            node(index).PRRlogs       = [node(index).PRRlogs TS_H_ED_count_PRR(3)];
            node(index).RSSI            = [node(index).RSSI  TS_H_ED_count_PRR(4)];
            % Get One Hop ED Values per Node
            if node(index).hops(end) == 1
                node(index).onehopRSSI = [node(index).onehopRSSI node(index).RSSI(end)];
            end
            
            if length(node(index).Timestamp) >=2
                if (node(index).Timestamp(end) < node(index).Timestamp(end-1))
                    node(index).TS_overflow = node(index).TS_overflow + 1;
                    node(index).Timestamp(end) = node(index).Timestamp(end) + TS_Overflow;
                end
            end
        end
    end
    line = fgets(logsFile);
    LineNum = LineNum +1;
end

%% printing summary
fprintf("Number of Lines Scanned: %d \n",LineNum);
fprintf("Number of Nodes Participated: %d \n",length(root.nodesIP));
fclose(logsFile);
%clear xx x flag index line logsFile IP IPtable

%% Recalculations
%Reformating the matrix
fprintf("Formating the Results...\n");
node(i).PRRcalcNew = [];
i = 1;
while (i <= length(node))
    j = 1;
    while (j <= length(node(i).count)-1)
        if (node(i).count(j) == 0)  || (node(i).count(j) == node(i).count(j+1))
            node(i).count(j)        = [];
            node(i).Timestamp(j)    = [];
            node(i).hops(j)         = [];
            node(i).RSSI(j)           = [];
            node(i).PRRcalcNew      = [];
            node(i).PRRlogs(j)      = [];
           node(i).onehopRSSI(j)     = [];
            j = j - 1;
        end
        j = j + 1;
    end
    i = i + 1;
    
end

% PRR calculation & Dividing PRR values per hour per node
fprintf("Calculating the PRR per Hour...\n");
for i = 1:length(node)
    L = 1;
    TimeLimit = node(i).Timestamp(L) + 3600;
    lastCount = node(i).count(1);
    for j = 1:length(node(i).count)
%         %count jumps 100 packets or more
        if lastCount - node(i).count(j) > 100
             fprintf("Warning: Jump in the count Value in %s at packet %d\n",node(i).number,length(node(i).count(1:j)));
             node(i).count_offset = node(i).count_offset + lastCount;
        end
        lastCount = node(i).count(j);
        node(i).count(j) = node(i).count(j) + node(i).count_offset;
        
        %Calculate PRR
        node(i).PRRcalcNew     = [node(i).PRRcalcNew 100*length(node(i).count(1:j))/max(node(i).count(1:j))];
        
        %dividing every hour
        if (node(i).Timestamp(j) > TimeLimit)
            node(i).PRRhrs = [node(i).PRRhrs node(i).PRRcalcNew(L:j)];
            L = j+1;
            TimeLimit = node(i).Timestamp(j) + 3600;
        end
    end
end



%% --------------- PLOTTING GRAPHS ---------------
fprintf("Ploting the graphs...\n");
% CDF of PRR with our equation for all nodes
figure(1)
x0=10; y0=110; width=550; height=400; set(gcf,'units','points','position',[x0,y0,width,height]);
for i = 1:length(node)
    hold on
    ecdf(node(i).PRRcalcNew);
    xlim auto;
    ylim auto;
end
legend1 = legend (node.number, 'location', 'northeastoutside');
legend1.FontSize = 14;
title(["CDF of PRR"; 'Parameters: Wake Up Rate = ',num2str(Rate), ',' ' Random Offset = ', num2str(randomNum), ',' ' Pushing Period = ' num2str(Push)],'FontSize', 20);
xlabel('PRR','FontSize', 18);
ylabel('P(PRR <= X)','FontSize', 18);
set(gca,'FontSize',14);
grid on



% Histogram of Number of Hops per Node
f5 = figure(2);
b = 1;
for i = 1:length(node)
subplot(4,4,b);
    histogram(node(i).hops,'Normalization','probability','BinMethod','integers');
    axis([0.5 5.5 0 1]);
    xticks([1,2,3,4,5])
    yticks([0 1]);
    ylim ([0 1]);
    xlabel('# hops','FontSize',18);
    ylabel('P(x)','FontSize',18);
    title(node(i).number);
    b=b+1;
    grid on
end
a = axes;
set(gca,'FontSize',14);
a.Visible = 'off'; % set(a,'Visible','off');
t1.Visible = 'on'; % set(t1,'Visible','on');



% Average PRR per Node
figure(3);
prr = [];
for i = 1:length(node)
    if length(node(i).PRRcalcNew) >=1
        prr = [prr node(i).PRRcalcNew(end)]; 
    end
end
hold on;
plot(prr,'o', 'MarkerSize',5,'MarkerFaceColor','blue')
xticklabels({node.number})
xticks(1:length(node))
ax = gca;
ax.YGrid = 'on';
ax.GridLineStyle = '-';
ylim auto;
title('Average PRR per Node','FontSize', 20);
ylabel('PRR (Packet Reception Rate)','FontSize', 20);
xlabel('Node Number','FontSize', 20);
set(gca,'FontSize',14);
hold off;


% CDF of RSSI Values for One Hop per Node
figure(4);
leg = [];
for i = 1:length(node)
    if length(node(i).onehopRSSI) >= 1
    hold on
    ecdf(node(i).onehopRSSI);
    xlim auto;
    ylim auto;
    leg= [leg i];
   
    end
    
end
legend show
title("CDF of RSSI Values for One Hop",'FontSize', 20);
xlabel('RSSI (Received Signal Strength Indication)','FontSize', 18);
ylabel('P(RSSI <= X)','FontSize', 18);
set(gca,'FontSize',14);
grid on



function value = getFromTo(line, from, to)
index = strfind(line,from) + strlength(from);
value =[];
while line(index) ~= to
    value = [value line(index)];
    index = index +1;
end
end

function value = getParam(line, name)
index = strfind(line,name) + strlength(name);
name = char(name);
if isempty(index)
   fprintf("Cannot find (%s) ",name(1:end-1));
   value = -1;
   return; 
end
value =[];
outLoop = 0;

while line(index) ~= "]"
    value = [value line(index)]; %#ok<*AGROW>
    index = index +1;
    outLoop = outLoop + 1;
    if (outLoop == 50) || (line(index) == newline)
        fprintf("Cannot Read (%s) ",name(1:end-1));
        value = '-1';
        break;
    end
end
value = str2num(value); %#ok<ST2NM>
end

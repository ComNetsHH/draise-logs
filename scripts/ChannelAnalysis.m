
clear
close all
clc

%% **API**************%
expName = '_BCH_0_withsensing';      % keyword from the experiment name and does not need to be exact full name
direct = 'C:\Users\zeynep\Documents\MATLAB\Draise_paper\';         % searching in the cloud logs path

CheckRootLogs = 1;  % 0 Root logs will be ignored;  1 Root logs will be scanned
SeparateEB = 1;     % 0 separate EB from data;      1 data and EB results are combined 

%plottingParameters%
plot_separateGraphs = 0;    % 0 all results on one graph; 1 figure for each channel or node
plot_Channels_xaxis = 1;    % 0 no plot; 1 plot prr vs channels on x axis
plot_Nodes_xaxis    = 1;    % 0 no plot; 1 plot prr vs nodes on x axis
%endPlottingParameters%
%**endAPI**************%

%% **definitions***************%
% IPtable = ["fd00::749:3239:314d:d433", "fd00::1b62:5333:3043:d539", "fd00::2345:6533:3043:d739", "fd00::1b51:5033:3043:d639", "fd00::1b51:6333:3043:d439", "fd00::1b51:6433:3043:d339", "fd00::2344:6533:3043:da39", "fd00::1b51:5633:3043:d639", "fd00::1b62:5133:3043:d739", "fd00::2344:6333:3043:d439", "fd00::2344:6233:3043:d639", "fd00::1b50:5933:3043:d239", "fd00::2345:5933:3043:d639", "fd00::736:3239:314d:d733", "fd00::1b51:4933:3043:d639"];
% IPtable = [IPtable; "node24", "node19", "node12", "node15", "node07", "node13", "node02", "node25", "node17", "node10", "node04", "node22", "node08", "node23", "node03"];

IPtable = ["fd00::1b50:5933:3043:d239", "fd00::736:3239:314d:d733", "fd00::1b51:5033:3043:d639", "fd00::742:3139:314d:d733", "fd00::2345:5933:3043:d639", "fd00::2342:6533:3043:d939", "fd00::1b51:4933:3043:d639", "fd00::1b51:6333:3043:d439", "fd00::2344:6233:3043:d639", "fd00::2344:6333:3043:d439"];
IPtable = [IPtable; "Node 24", "Node 19", "Node 15", "Node 7", "Node 13", "Node 25", "Node 17", "Node 10", "Node 4", "Node 23"];

node.name = [];
node.IP = [];
node.isRoot = 0;
node.channel.number = [];
if SeparateEB == 1
    node.channel.successEB = [];
    node.channel.nackEB = [];
    node.channel.totalEB = 0;    
end
node.channel.success = [];
node.channel.nack = [];
node.channel.total = 0;
%**endDefinitions***************%


%**Validating the inputs**********************%
listing = dir([direct '**/*' expName '*.log']);
if length(listing)<= 0
    disp('No such experiments in this directory.. please recheck the name or the directory');
    return;
end

%removing duplicated files
[~,ii] = unique({listing.name},'stable');
listing = listing(ii);

%**printing preliminary results*****%
fprintf('Number of Experiments found with name %s = %d :- \n',expName,length(listing));

%% Collecting Data from log files Section

%**Loop on all Logs found****%
nodeIndex = 1;
for num = 1: length(listing)
    
    %Opening the file%
    logsFile = fopen([listing(num).folder '\' listing(num).name],'r');
    fprintf("\nCollecting the data from the log file %d out of %d.",num,length(listing));
    
    %Begin scanning%
    line = fgets(logsFile);
    LineNum = 1;
    
    %ignore if Root or other not NODE Logs%
    skipFile = 1;
    while LineNum<10 && ischar(line)
%         if contains(line,'Choosen as role Host')
          if contains(line,'Device role: NODE')            
            node(nodeIndex).isRoot = 0;
            skipFile = 0;
            break;
        elseif (contains(line,'Device role: ROOT') && CheckRootLogs)
            skipFile = 0;
            node(nodeIndex).isRoot = 0;
            break;
        end
        line = fgets(logsFile);
        LineNum = LineNum +1;
    end
    
    if skipFile == 1
        fprintf('\nFile %s is not valid\n',listing(num).name);
        continue;
    end
    
    %initialization%
    node(nodeIndex).name = listing(num).name(1:6);
    node(nodeIndex).IP = IPtable(find(~cellfun('isempty',strfind(IPtable,node(nodeIndex).name)))-1);
    node(nodeIndex).channel.number = [];
    if SeparateEB == 1
        node(nodeIndex).channel.successEB = [];
        node(nodeIndex).channel.nackEB = [];
        node(nodeIndex).channel.totalEB = 0;    
    end
    node(nodeIndex).channel.success = [];
    node(nodeIndex).channel.nack = [];
    node(nodeIndex).channel.total = 0;
    node(nodeIndex).channel.prr = 0;
    node(nodeIndex).channel.prrEB = 0;
    
    %Scanning the log file%
    while ischar(line)
        
        %loading points move every 10,000 line
        if isequal(mod(LineNum,10000),0)
            loadingPoints(LineNum);
        end
        
        %checking keywords
        if length(line)>5
            if contains(line,' ch-')
                chIndex = getChannel(line);
                if chIndex == -1
                    line = fgets(logsFile);
                    LineNum = LineNum +1;
                    continue;
                end
                
                %get the channel index%
                if isempty([node(nodeIndex).channel.number])
                    node(nodeIndex).channel.number = chIndex;
                    chIndex = 1;
                elseif isempty(find([node(nodeIndex).channel.number] == chIndex, 1))
                    node(nodeIndex).channel = [node(nodeIndex).channel node(nodeIndex).channel(1)];
                    node(nodeIndex).channel(end).number = chIndex;
                    if SeparateEB == 1
                         node(nodeIndex).channel(end).successEB = [];
                         node(nodeIndex).channel(end).nackEB = [];
                         node(nodeIndex).channel(end).totalEB = 0;    
                    end
                    node(nodeIndex).channel(end).success = [];
                    node(nodeIndex).channel(end).nack = [];
                    node(nodeIndex).channel(end).total = 0;
                    chIndex = length(node(nodeIndex).channel);
                else
                    chIndex = find([node(nodeIndex).channel.number] == chIndex);
                end
                
                %Assign results of the channel%
                [x, y] = getxy(line);
                if SeparateEB == 1
                    if isData(line) == 0
                        node(nodeIndex).channel(chIndex).totalEB = node(nodeIndex).channel(chIndex).totalEB +1;
                        if x == 0
                            node(nodeIndex).channel(chIndex).successEB = [node(nodeIndex).channel(chIndex).successEB y];
                        else
                            node(nodeIndex).channel(chIndex).nackEB = [node(nodeIndex).channel(chIndex).nackEB y];
                        end
                    else
                        node(nodeIndex).channel(chIndex).total = node(nodeIndex).channel(chIndex).total +1;
                        if x == 0
                            node(nodeIndex).channel(chIndex).success = [node(nodeIndex).channel(chIndex).success y];
                        else
                            node(nodeIndex).channel(chIndex).nack = [node(nodeIndex).channel(chIndex).nack y];
                        end
                    end
                else
                    node(nodeIndex).channel(chIndex).total = node(nodeIndex).channel(chIndex).total +1;
                    if x == 0
                        node(nodeIndex).channel(chIndex).success = [node(nodeIndex).channel(chIndex).success y];
                    else
                        node(nodeIndex).channel(chIndex).nack = [node(nodeIndex).channel(chIndex).nack y];
                    end
                end
            end
        end
        line = fgets(logsFile);
        LineNum = LineNum +1;
    end
    
    if isempty([node(nodeIndex).channel.number])
    fprintf("\nNo Results found in ""%s""",listing(num).name);
        node(nodeIndex) = [];
    end
    
    fclose(logsFile);
    fprintf("\nFile ""%s"" closed.\n",listing(num).name);
    nodeIndex = nodeIndex + 1;
    
end

%Calculations%

%remove empty structs
idx = ~cellfun('isempty',{node.name});
node = node(idx);

%Check if no results found%
if isempty([node.name])
    disp('!!No Results found in this directory!!.. please recheck the experiment name or the directory');
    return;
end

%% Calculations and graph plotting Section

%sort channels ascendingly
chNode = sort([node(1).channel.number]);
prr = zeros(length(node),length(chNode));
prrEB = zeros(length(node),length(chNode));
for n = 1:length(node)
    Nchannels = [node(n).channel.number];
    for c = 1:length(chNode)
        index = find(Nchannels == chNode(c));
        node(n).channel(index).prr = 100*length(node(n).channel(index).success)/node(n).channel(index).total;
        prr(n,c) = node(n).channel(index).prr;
%         node(n).channel(index).prrEB = 100*length(node(n).channel(index).successEB)/node(n).channel(index).totalEB;
%         prrEB(n,c) = node(n).channel(index).prrEB;
    end
end
%endCalculations%

%printing summary for the results%
disp('Summary:-');
[n, c] = find(max(max(prr)) == prr);
fprintf('Maximum prr is %2.2f found %d times, first in %s on channel %d\n',max(max(prr)),length(n),node(n(1)).name,chNode(c(1)));
[n, c] = find(min(min(prr)) == prr);
fprintf('Minimum prr is %2.2f found %d times, first in %s on channel %d\n',min(min(prr)),length(n),node(n(1)).name,chNode(c(1)));


%plotting Graphs%
%%%
[nds, chs] = size(prr);
if plot_Nodes_xaxis == 1
    figure()
    for i = 1:chs
        if plot_separateGraphs == 1 && i ~= 1
            figure()
        end
        hold on;
        plot(prr(:,i),getMarker(i),'MarkerSize',10,'DisplayName',['ch-' num2str(chNode(i))])
        xticklabels({node.name})
        xticks(1:length(node))
        ax = gca;
        ax.YGrid = 'on';
        ax.GridLineStyle = '-';
        ylim ([0 100]);
        title(['PRR for ch-' num2str(chNode(i))],'FontSize', 20);
        ylabel('PRR (Packet Reception Rate)','FontSize', 20);
        xlabel('Node Number','FontSize', 20);
        set(gca,'FontSize',14);
        hold off;
    end
    if plot_separateGraphs == 0
        title('PRR per Nodes','FontSize', 20);
        ylabel('PRR (Packet Reception Rate)','FontSize', 20);
        xlabel('Node Number','FontSize', 20);
        legend('Location','northeastoutside');
    end
%     figure()
%     for i = 1:chs
%         if plot_separateGraphs == 1 && i ~= 1
%             figure()
%         end
%         hold on;
%         plot(prrEB(:,i),getMarker(i),'MarkerSize',10,'DisplayName',['ch-' num2str(chNode(i))])
%         xticklabels({node.name})
%         xticks(1:length(node))
%         ax = gca;
%         ax.YGrid = 'on';
%         ax.GridLineStyle = '-';
%         ylim ([0 100]);
%         title(['EB PRR for ch-' num2str(chNode(i))],'FontSize', 20);
%         ylabel('EB PRR (Packet Reception Rate)','FontSize', 20);
%         xlabel('Node Number','FontSize', 20);
%         set(gca,'FontSize',14);
%         hold off;
%     end
%     if plot_separateGraphs == 0
%         title('EB PRR per Nodes','FontSize', 20);
%         ylabel('EB PRR (Packet Reception Rate)','FontSize', 20);
%         xlabel('Node Number','FontSize', 20);
%         legend('Location','northeastoutside');
%     end
end

if plot_Channels_xaxis == 1
    figure()
    for i = 1:nds
        if plot_separateGraphs == 1 && i ~= 1
            figure()
        end
        hold on;
        plot(prr(i,:),getMarker(i),'MarkerSize',10,'DisplayName',node(i).name)
        xticklabels(chNode)
        xticks(1:length(chNode))
        ax = gca;
        ax.YGrid = 'on';
        ax.GridLineStyle = '-';
        ylim ([0 100]);
        title(['PRR for Node ' node(i).name(end-1:end)],'FontSize', 20);
        ylabel('PRR (Packet Reception Rate)','FontSize', 20);
        xlabel('Channel Numbers','FontSize', 20);
        set(gca,'FontSize',14);
        hold off;
    end
    if plot_separateGraphs == 0
        title('PRR per Channels','FontSize', 20);
        ylabel('PRR (Packet Reception Rate)','FontSize', 20);
        xlabel('Channel Number','FontSize', 20);
        legend('Location','northeastoutside');
    end
%     figure()
%     for i = 1:nds
%         if plot_separateGraphs == 1 && i ~= 1
%             figure()
%         end
%         hold on;
%         plot(prrEB(i,:),getMarker(i),'MarkerSize',10,'DisplayName',node(i).name)
%         xticklabels(chNode)
%         xticks(1:length(chNode))
%         ax = gca;
%         ax.YGrid = 'on';
%         ax.GridLineStyle = '-';
%         ylim ([0 100]);
%         title(['EB PRR for Node ' node(i).name(end-1:end)],'FontSize', 20);
%         ylabel('EB PRR (Packet Reception Rate)','FontSize', 20);
%         xlabel('Channel Numbers','FontSize', 20);
%         set(gca,'FontSize',14);
%         hold off;
%     end
%     if plot_separateGraphs == 0
%         title('EB PRR per Channels','FontSize', 20);
%         ylabel('EB PRR (Packet Reception Rate)','FontSize', 20);
%         xlabel('Channel Number','FontSize', 20);
%         legend('Location','northeastoutside');
%     end
end
%%%
%

%Functions%
%Loading 3 points%
function loadingPoints(stat)
stat = mod(stat,3);
if stat==0
    fprintf('\b\b');
else
    fprintf('.');
end
end

%get the channel number in case of unicast and trasmission or -1 otherwise%
function value = getChannel(line)
value = -1;
if contains(line,' st ')
    value = str2double(extractBetween(line," ch-","} "));
end
end

%change marker symbol when plotting the graphs%
function marker = getMarker(i)
markers = {'+','o','*','.','x','s','d','^','v','>','<','p','h'};
marker = markers{mod(i,numel(markers))+1};
end

%extract x and y from the line where st(x-y)%
function [x, y] = getxy(line)
xy = extractAfter(line,", st ");
if length(xy) > 6
    str = strsplit(xy,', ');
    xy = str{1};
end
xy = strsplit(xy,'-');
x = str2double(xy{1});
y = str2double(xy{2});
end

%Check wether the packet is Data or EB%
function isdata = isData(line)
isdata = 1;    
if contains(line,' bc-1')
    isdata = 0;
end
end
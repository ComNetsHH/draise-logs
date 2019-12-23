clear
close all
clc

filesPaths = [
    
    "node13_BCH_0_withsensing.log"
    "node17_BCH_0_withsensing.log"
    "node19_BCH_0_withsensing.log"
    "node23_BCH_0_withsensing.log"
    "node24_BCH_0_withsensing.log"
    "node25_BCH_0_withsensing.log"
    "node13_BL_0_30_3_3_test3.log"
    "node17_BL_0_30_3_3_test3.log"
    "node19_BL_0_30_3_3_test3.log"
    "node23_BL_0_30_3_3_test3.log"
    "node24_BL_0_30_3_3_test3.log"
    "node25_BL_0_30_3_3_test3.log"
];
Nodes = ["Node 13 - BCH"; "Node 17 - BCH"; "Node 19 - BCH"; "Node 23 - BCH"; "Node 24 - BCH"; "Node 25 - BCH"; "Node 13 - SFSB"; "Node 17 - SFSB"; "Node 19 - SFSB"; "Node 23 - SFSB"; "Node 24 - SFSB" ; "Node 25 - SFSB"];


node.delay = [];

errmsg = '';
for i = 1:length(filesPaths)
   [fileID,errmsg] = fopen(filesPaths(i),'r');
   if fileID>0
       fprintf("File %d: Processing\n",i);
         node(i).delay = [];
       line = fgets(fileID);
       while ischar(line)
           if contains(line,"Got response for packet number")
              node(i).delay = [node(i).delay getDelay(line)];
           end
           line = fgets(fileID);
       end
       fclose(fileID);
   else
       fprintf("File %d: %s\n",i,errmsg);
   end
end

figure(1)
for i = 1:length(node)
    hold on
    ecdf(node(i).delay);
    xlim auto;
    ylim auto;
end
legend1 = legend (Nodes, 'location', 'northeastoutside');
legend1.FontSize = 14;
title("CDF of Round Trip Time (RTT)",'FontSize', 30);
xlabel('Round Trip Time [ms]','FontSize', 20);
ylabel('P(RTT <= X)','FontSize', 20);
set(gca,'FontSize',20);
grid on


function value = getDelay(line)
index = 1;
value = -1;
index = strfind(line, 'within') + 6;
value = str2num(line(index+1:end))
end
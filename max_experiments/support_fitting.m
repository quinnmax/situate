
file = load('/Users/Max/Desktop/external support recording_2017.02.27.13.53.18/external support recording_split_01_condition_1_2017.02.27.14.23.57.mat');

%%

col_descriptions = {'object type', 'internal support', 'sample density', 'ground truth IOU'};
regression_data =  cell( 0, length(col_descriptions) );
for fi = 1:length(file.agent_records)
    
    cur_agent_records = file.agent_records{fi};
    
    for ai = 1:length(cur_agent_records)
        cur_agent = cur_agent_records(ai);
        cur_data = { cur_agent.interest cur_agent.support.internal, cur_agent.support.sample_densities, cur_agent.support.GROUND_TRUTH };
        regression_data(end+1,:) = cur_data;
    end
    
    fprintf('.');
    
end
fprintf('\n');

%% hist

objects = unique(regression_data(:,1));
for oi = 1:length(objects)
    
    cur_obj = objects{oi};
    obj_data = cell2mat( regression_data( strcmp(cur_obj,regression_data(:,1) ), 2:end ) );
    
    subplot2(length(objects),3, oi, 1);
    hist(obj_data(:,1),50);
    ylabel(cur_obj);
    title('internal support')
    
    subplot2(length(objects),3, oi, 2);
    hist(obj_data(:,2),50);
    title('sample density')
    
    subplot2(length(objects),3, oi, 3);
    hist(obj_data(:,3),50);
    title('gt IOU')
    
end

%% log hist

objects = unique(regression_data(:,1));

for oi = 1:length(objects)
    
    cur_obj = objects{oi};
    obj_data_initial = cell2mat( regression_data( strcmp(cur_obj,regression_data(:,1) ), 2:end ) );
    obj_data = obj_data_initial(obj_data_initial(:,1)>=0,:);
    
    subplot2(length(objects),3, oi, 1);
    hist(log(obj_data(:,1) + .0001),50);
    ylabel(cur_obj);
    title('log internal support')
    
    subplot2(length(objects),3, oi, 2);
    hist(log(obj_data(:,2)),50);
    title('log sample density')
    
    subplot2(length(objects),3, oi, 3);
    hist(obj_data(:,3),50);
    title('gt IOU')
    
end

%% scatters

objects = unique(regression_data(:,1));

for oi = 1:length(objects)
    
    cur_obj = objects{oi};
    obj_data_initial = cell2mat( regression_data( strcmp(cur_obj,regression_data(:,1) ), 2:end ) );
    obj_data = obj_data_initial(obj_data_initial(:,1)>=0,:);
    
    subplot2(length(objects),3, oi, 1);
    plot(obj_data(:,1), log(obj_data(:,2)),'.');
    title('internal v density');
    ylabel(cur_obj);
    
    subplot2(length(objects),3, oi, 2);
    plot(obj_data(:,1), obj_data(:,3),'.');
    title('internal v IOU');
    
    subplot2(length(objects),3, oi, 3);
    plot(log(obj_data(:,2)),obj_data(:,3),'.');
    title('density v IOU');
    
end

%% fit

x = [obj_data(:,1) log(obj_data(:,2)) obj_data(:,1).*log(obj_data(:,2))];
y = [obj_data(:,3)];

dist = 'normal';
link = 'identity';

b = glmfit(x, y, dist);
yhat = glmval(b,x, link);

plot(y,yhat,'.')
xlabel('actual IOU');
ylabel('predicted IOU');







    
  



    
    
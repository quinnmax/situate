
%% 

load('/Users/Max/Desktop/looking_at_records_exp_2017.01.19.13.51.19/looking_at_records_exp_split_01_condition_1_2017.01.19.14.00.25.mat');

%% 

support = [agent_records{1}.support];
box     = [agent_records{1}.box];

inds_dog    = strcmp({agent_records{1}.interest},'dog');
inds_person = strcmp({agent_records{1}.interest},'dogwalker');
inds_leash  = strcmp({agent_records{1}.interest},'leash');

%%

support_cnn = [support.internal];
support_iou = [support.GROUND_TRUTH];
aspect_ratio = [box.aspect_ratio];
area_ratio = [box.area_ratio];

% restrict to a tight range of aspect and area, then look at the
% relationship between cnn support and ground truth

ind_groups = {inds_dog, inds_person, inds_leash};
group_descriptions = {'dogs', 'walkers', 'leashes'};

for oi = 1:length(ind_groups)
    
    cur_obj_inds = ind_groups{oi};

    aspect_band = prctile( aspect_ratio(cur_obj_inds), [20 80] );
    area_band   = prctile( area_ratio(cur_obj_inds),   [25 75] );

    %x = [cur_obj_inds' ...
    %    (aspect_ratio >= aspect_band(1))' ...
    %    (aspect_ratio <= aspect_band(2))' ...
    %    (area_ratio   >= area_band(1))' ...
    %    (area_ratio   <= area_band(2))' ];
    
    cur_inds = ...
        cur_obj_inds                     .* ...
        (aspect_ratio >= aspect_band(1)) .* ...
        (aspect_ratio <= aspect_band(2)) .* ...
        (area_ratio   >= area_band(1))   .* ...
        (area_ratio   <= area_band(2))   ;
    cur_inds = logical(cur_inds);
    
    %cur_inds = logical(prod(x,2));

    temp_corrcoef = corrcoef(support_cnn(cur_inds),support_iou(cur_inds));
    cc = temp_corrcoef(1,2);
    
    figure
        plot(support_cnn(cur_inds),support_iou(cur_inds),'.','markersize',20);
        xlabel('cnn score');
        ylabel('iou');
        title(group_descriptions{oi});
        legend(num2str(cc),'location','southeast');
    
end

%% take a look in 3d

for oi = 1:length(ind_groups)
    
    cur_obj_inds = ind_groups{oi};
    cur_inds = cur_obj_inds;
    
    figure
    color_mat = [support_cnn' zeros(length(support_cnn),1) zeros(length(support_cnn),1)];
    scatter3(log(area_ratio(cur_inds)),log(aspect_ratio(cur_inds)),support_iou(cur_inds),[],color_mat(cur_inds,:),'filled');
    xlabel('area');
    ylabel('aspect');
    zlabel('iou');
    title(group_descriptions{oi});
    
end












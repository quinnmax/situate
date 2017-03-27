


%fname            = '/Users/Max/Desktop/external support recording_2017.02.27.13.53.18/external support recording_split_01_condition_1_2017.02.27.14.23.57.mat';
fname            = '/Users/Max/Desktop/external support recording_2017.02.27.13.53.18/external support recording_split_01_condition_1_2017.02.27.14.23.57.mat';
data             = load(fname);
sample_densities = [];
gt_iou           = [];
internal_support = [];
object_type      = {};



for imi = 1:length(data.agent_records)
    temp_support = [data.agent_records{imi}.support];
    object_type = [object_type {data.agent_records{imi}.interest}];
    sample_densities = [sample_densities temp_support(:).sample_densities];
    gt_iou = [gt_iou temp_support(:).GROUND_TRUTH];
    internal_support = [internal_support temp_support(:).internal];
    progress(imi,length(data.agent_records));
end



target_objects = {'dog','dogwalker','leash'};
for target_obj_ind = 1:length(target_objects)
    target_obj = target_objects{ target_obj_ind };

    inds_keep = (internal_support >= 0) & strcmp(object_type,target_obj);
    inds_keep = find(inds_keep);

    iou_pad = .00001 * randn(1,length(inds_keep));
    gt_iou_padded = gt_iou(inds_keep) + iou_pad - min(iou_pad) + .000001;
    internal_support_padded = internal_support(inds_keep) + .0001;
    sample_densities_padded = sample_densities(inds_keep);

    figure;

        subplot(3,2,1);
        hist(sample_densities_padded,50)
        xlabel('sample density');
        title({'agent records';'50 images';target_obj});

        subplot(3,2,2);
        hist(log(sample_densities_padded),50);
        xlabel('log sample density');

        subplot(3,2,3);
        hist(gt_iou_padded,50)
        xlabel('iou');

        subplot(3,2,4);
        hist(log(gt_iou_padded),50);
        xlabel('log iou');

        subplot(3,2,5);
        hist(internal_support_padded,50)
        xlabel('internal support');

        subplot(3,2,6);
        hist(log(internal_support_padded),50);
        xlabel('log internal support');

    color_func = @(x) [x 0 1-x];  
    color = zeros(0,3);
    for i = 1:length(inds_keep)
        color(i,:) = color_func(gt_iou(inds_keep(i)));
    end

    [~,ordering] = sort( gt_iou(inds_keep), 'ascend');
    figure;
    scatter(log(sample_densities_padded(ordering)),(internal_support_padded(ordering)),100,color(ordering,:),'filled');
    xlabel('log sample density');
    ylabel('internal support');
    title(target_obj);

    x = [(internal_support(inds_keep)+.01)' log(sample_densities(inds_keep))' (internal_support(inds_keep)+.01)'.*log(sample_densities(inds_keep))'];
    y = gt_iou(inds_keep);
    distribution = 'binomial';
    link = 'logit';
    [b,dev,stats] = glmfit(x,y',distribution,'link',link);

    y_hat = glmval(b,x,link);

    figure()
    plot(y,y_hat,'.')
    xlabel('iou');
    ylabel('predicted iou');
    title(target_obj);

end

    




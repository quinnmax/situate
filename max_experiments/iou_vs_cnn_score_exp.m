load('/Users/Max/Desktop/looking_at_records_exp_2017.01.19.13.51.19/looking_at_records_exp_split_01_condition_1_2017.01.19.14.00.25.mat');

support = [agent_records{1}.support];
inds_dog    = strcmp({agent_records{1}.interest},'dog');
inds_person = strcmp({agent_records{1}.interest},'dogwalker');
inds_leash  = strcmp({agent_records{1}.interest},'leash');

%%

support_dog_cnn     = [support(inds_dog).internal];
support_person_cnn  = [support(inds_person).internal];
support_leash_cnn   = [support(inds_leash).internal];

support_dog_gt      = [support(inds_dog).GROUND_TRUTH];
support_person_gt   = [support(inds_person).GROUND_TRUTH];
support_leash_gt    = [support(inds_leash).GROUND_TRUTH];

support_dog_cnn     = log(support_dog_cnn    + .0001 );
support_person_cnn  = log(support_person_cnn + .0001 );
support_leash_cnn   = log(support_leash_cnn  + .0001 );
support_dog_gt      = log(support_dog_gt     + .0001 );
support_person_gt   = log(support_person_gt  + .0001 );
support_leash_gt    = log(support_leash_gt   + .0001 );

cc_dog      = corrcoef(support_dog_cnn,support_dog_gt);
cc_person   = corrcoef(support_person_cnn,support_person_gt);
cc_leash    = corrcoef(support_leash_cnn,support_leash_gt);
cc_dog = cc_dog(1,2);
cc_person = cc_person(1,2);
cc_leash = cc_leash(1,2);


%%


figure

subplot(1,3,1)
plot( support_dog_cnn, support_dog_gt, '.','Markersize',20 );
legend(num2str(cc_dog));
title('dog');
xlabel('cnn');
ylabel('gt iou');

subplot(1,3,2)
plot( support_person_cnn, support_person_gt, '.','Markersize',20 );
legend(num2str(cc_person));
title('person');
xlabel('cnn');
ylabel('gt iou');

subplot(1,3,3)
plot( support_leash_cnn, support_leash_gt, '.','Markersize',20 );
legend(num2str(cc_leash));
title('leash');
xlabel('cnn');
ylabel('gt iou');




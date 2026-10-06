##########
# Set-Up #
##########

## Remove pre-loaded variables/references for a clean slate
rm(list=ls())
## Load necessary packages 

library(tidyverse)
library(lmerTest)
library(patchwork)
library(ggExtra)

## Set working directory (folder in which the data files are saved)

## Read in the dataset
### Young Adult Dataset: DurationsMaster_YAall_ICPhS_Final.csv
### Older Adult Dataset: DurationsMaster_OAall_ICPhS_Final.csv
DurationsMaster <- read_csv("DurationsMaster_YAall_ICPhS_Final.csv")

## Subset the data by language of the paragraph
DurationsMaster_Eng <- subset(DurationsMaster, DefaultLang == "Eng")
DurationsMaster_Span <- subset(DurationsMaster, DefaultLang == "Span")

## Input dataset is in long format
## Speech rate uses acoustic syllables and is given in syll/sec
## Ensure paragraph, participant, code switching condition, and region IDs are factors
rateAll_long <- DurationsMaster %>%
  mutate(
    CS_cond = as.factor(CS_cond),
    Particip_ID = as.factor(Particip_ID),
    Region = as.factor(Region),
    Pgph = as.factor(Pgph)
  )

## New dataframe: Avg speech rate (syll/sec) by condition 
asyll_summ_long <- rateAll_long %>%
  group_by(Particip_ID, DefaultLang, Dom_lang, BLI_Score, CS_cond) %>%
  summarise(
    avg_rate = mean(speechrate, na.rm = TRUE),
    .groups = "drop"
  )

asyll_summ_long_means_perparticip <- rateAll_long %>%
  group_by(Particip_ID, DefaultLang, Dom_lang, BLI_Score) %>%
  summarise(
    participant_mean = mean(speechrate, na.rm = TRUE),
    .groups = "drop"
  )

defxdomlang_acrossptcpt_ratemeans <- asyll_summ_long_means_perparticip %>%
  group_by(Dom_lang, DefaultLang) %>%
  summarise(
    N = n(),
    M = mean(participant_mean),
    SD = sd(participant_mean),
    .groups = "drop"
  )

## Statistical Model of the dataset 

### Recode Region into a binary contrast-coded variable: 
### level "0" = -0.5, all other levels = 0.5

rateAll_long$Region <- factor(rateAll_long$Region)
rateAll_long$Region_bin <- ifelse(rateAll_long$Region == "0", -0.5, 0.5)

### Create fncn to scale sum contrasts by multiplying standard sum coding by 0.5

contr.sum.half <- function(n) contr.sum(n) * 0.5

### Rescaled sum coding of binary factors (±0.5 contrasts)

rateAll_long$CS_cond <- factor(rateAll_long$CS_cond)
contrasts(rateAll_long$CS_cond) <- contr.sum.half(2)

rateAll_long$DefaultLang <- factor(rateAll_long$DefaultLang)
contrasts(rateAll_long$DefaultLang) <- contr.sum.half(2)

## OA dataset only: Include Dom_lang
#rateAll_long$Dom_lang <- factor(rateAll_long$Dom_lang)
#contrasts(rateAll_long$Dom_lang) <- contr.sum.half(2)

### Verify applied contrast coding (OA dataset only: include Dom_lang)
contrasts(rateAll_long$CS_cond) 
contrasts(rateAll_long$DefaultLang)
#contrasts(rateAll_long$Dom_lang)
  
## Linear mixed-effects model predicting speech rate from language context
## (CS_cond: single vs. mixed language) and the default language of a paragraph 
## (DefaultLang: Spanish vs. English)

model_rate_main <- lmer(speechrate ~ CS_cond * DefaultLang +
                                 (1 | Particip_ID) + 
                                 (1 | Pgph), 
                               data = rateAll_long)
summary(model_rate_main)

## Follow-up model for older adult dataset only including dominant language as predictor

#model_rate_OA_addl <- lmer(speechrate ~ CS_cond * DefaultLang * Dom_lang + 
#                                 (1 | Particip_ID) + 
#                                 (1 | Pgph), 
#                               data = rateAll_long)
#summary(model_rate_OA_addl)


## Data Visualizations

### Histograms of Syllable Counts

ggplot(DurationsMaster, aes(x = nsyll)) +
  geom_histogram(binwidth = 1, fill = "grey", color = "black") +
  labs(x = "Syllable Count", y = "Frequency") +
  theme_minimal()

ggplot(DurationsMaster, aes(x = nsyll)) +
  geom_histogram(binwidth = 1, fill = "grey", color = "black") +
  labs(x = "Syllable Count", y = "Frequency") +
  theme_minimal() +
  coord_cartesian(xlim = c(0, 26))

### Speech rate  

#### Avg speech rate scatter with marginal histograms

avgrate_wide <- asyll_summ_long %>%
  pivot_wider(names_from = CS_cond, values_from = avg_rate)

#### Plot for Young Adults

#### English Default Only
#### Datapoints colored by dominant language: Coral = Eng, Teal = Span
#### Note: All YA ptcpnts are Eng Dominant

avgscatter_eng <- ggplot(filter(avgrate_wide, DefaultLang == "Eng"),
                aes(x = single, y = mixed, color = Dom_lang)) +
  geom_point(alpha = 0.7, size = 2) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "black") +
  scale_x_continuous(limits = c(2.5, 4.9)) +
  scale_y_continuous(limits = c(2.5, 4.9)) +
  labs(
    x = "Single Language Rate (syll/sec)",
    y = "Mixed Language Rate (syll/sec)",
    #title = "ENG"
  ) +
  theme_light()+
  theme(legend.position = "none")

avgscatter_eng <- ggMarginal(avgscatter_eng, type = "histogram", bins = 10)
avgscatter_eng

# Spanish dominant only
avgscatter_span <- ggplot(filter(avgrate_wide, DefaultLang == "Span"),
                 aes(x = single, y = mixed, color = Dom_lang)) +
  geom_point(alpha = 0.7, size = 2) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "black") +
  scale_x_continuous(limits = c(2.5, 4.9)) +
  scale_y_continuous(limits = c(2.5, 4.9)) +
  labs(
    x = "Single Language Rate (syll/sec)",
    y = "Mixed Language Rate (syll/sec)",
    #title = "SPAN"
  ) +
  theme_light()+
  theme(legend.position = "none")

avgscatter_span <- ggMarginal(avgscatter_span, type = "histogram", bins = 10)
avgscatter_span

# Stitch them together
wrapped_span_avgscatter <- wrap_elements(avgscatter_span)
wrapped_eng_avgscatter <- wrap_elements(avgscatter_eng)
combinedplot_YA <- wrapped_eng_avgscatter | wrapped_span_avgscatter
combinedplot_YA

#### Plot for Older Adults

#### English Default Only
#### Datapoints colored by dominant language: Coral = Eng, Teal = Span

avgscatter_eng2 <- ggplot(filter(avgrate_wide, DefaultLang == "Eng"),
                         aes(x = single, y = mixed, color = Dom_lang)) +
  geom_point(alpha = 0.7, size = 2) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "black") +
  scale_x_continuous(limits = c(2.5, 4.9)) +
  scale_y_continuous(limits = c(2.5, 4.9)) +
  labs(
    x = "Single Language Rate (syll/sec)",
    y = "Mixed Language Rate (syll/sec)",
    #title = "ENG"
  ) +
  theme_light()+
  theme(legend.position = "none")

avgscatter_eng2 <- ggMarginal(avgscatter_eng2, type = "histogram", bins = 8)
avgscatter_eng2

# Spanish dominant only
avgscatter_span2 <- ggplot(filter(avgrate_wide, DefaultLang == "Span"),
                          aes(x = single, y = mixed, color = Dom_lang)) +
  geom_point(alpha = 0.7, size = 2) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "black") +
  scale_x_continuous(limits = c(2.5, 4.9)) +
  scale_y_continuous(limits = c(2.5, 4.9)) +
  labs(
    x = "Single Language Rate (syll/sec)",
    y = "Mixed Language Rate (syll/sec)",
    #title = "SPAN"
  ) +
  theme_light()+
  theme(legend.position = "none")

avgscatter_span2 <- ggMarginal(avgscatter_span2, type = "histogram", bins = 8)
avgscatter_span2

# Stitch them together
wrapped_span_avgscatter2 <- wrap_elements(avgscatter_span2)
wrapped_eng_avgscatter2 <- wrap_elements(avgscatter_eng2)
combinedplot_OA <- wrapped_eng_avgscatter2 | wrapped_span_avgscatter2
combinedplot_OA



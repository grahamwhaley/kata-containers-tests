#!/usr/bin/env Rscript

library(ggplot2)	# ability to plot nicely
library(gridExtra)	# So we can plot multiple graphs together
suppressMessages(suppressWarnings(library(ggpubr)))		# for ggtexttable
suppressMessages(library(jsonlite))		# to load the data

testname="Container PSS footprint"

resultdirs=c(
	"results/kata",
	"results/devmap_loop",
	"results/runc"
	)

resultsfiles=c(
	"fio-rand-RW-128.json",
	"fio-rand-RW-256.json",
	"fio-rand-RW-512.json",
	"fio-rand-RW-1k.json",
	"fio-rand-RW-2k.json",
	"fio-rand-RW-4k.json",
	"fio-rand-RW-8k.json",
	"fio-rand-RW-16k.json",
	"fio-rand-RW-32k.json",
	"fio-rand-RW-64k.json"
)

data=c()
stats=c()
rstats=c()
rstats_names=c()

# For each set of results
for (currentdir in resultdirs) {
	count=1
	dirstats=c()
	for (resultsfile in resultsfiles) {
		fname=paste(currentdir, resultsfile, sep="/")
		if ( !file.exists(fname)) {
			warning(paste("Skipping non-existent file: ", fname))
			next
		}

		# Derive the name from the test result dirname
		datasetname=basename(currentdir)

		# Import the data
		fdata=fromJSON(fname)

		blocksize=fdata$global$bs

		cdata=data.frame(read_bw_kps=as.numeric(fdata$jobs$read$bw))
		cdata=cbind(cdata, write_bw_kps=as.numeric(fdata$jobs$write$bw))

		cdata=cbind(cdata, runtime=rep(datasetname, length(cdata[, "read_bw_kps"]) ))
		cdata=cbind(cdata, blocksize=rep(blocksize, length(cdata[, "read_bw_kps"]) ))

		# Calculate some stats for total time
#		sdata=data.frame(workload_mean=mean(cdata$workload))
#		sdata=cbind(sdata, workload_min=min(cdata$workload))

		# Store away as a single set
		data=rbind(data, cdata)
#		stats=rbind(stats, sdata)

		# Store away some stats for the text table
#		dirstats[count]=round(fdata.mean, digits=2)

		count = count + 1
	}
#	rstats=rbind(rstats, dirstats)
#	rstats_names=rbind(rstats_names, datasetname)
}

#rstats=cbind(rstats_names, rstats)

#unts=c("Kb", "Kb")

# If we have only 2 sets of results, then we can do some more
# stats math for the text table
if (length(resultdirs) == 2) {
	# This is a touch hard wired - but we *know* we only have two
	# datasets...
#	diff=c("diff")
#	val = ((as.double(rstats[1,2]) / as.double(rstats[2,2])) * 100) - 100
#	diff[2] = round(val, digits=2)
#	val = ((as.double(rstats[1,3]) / as.double(rstats[2,3])) * 100) - 100
#	diff[3] = round(val, digits=2)
#	rstats=rbind(rstats, diff)

#	unts[3]="%"
}

#rstats=cbind(rstats, unts)

# Set up the text table headers
#colnames(rstats)=c("Results", "blah", "Units")


# Build us a text table of numerical results
#stats_plot = suppressWarnings(ggtexttable(data.frame(rstats),
#	theme=ttheme(base_size=10),
#	rows=NULL
#	))

# plot how samples varioed over  'time'
if (0) {
point_plot <- ggplot() +
	geom_point( data=data, aes(count, workload, color=runtime), position=position_dodge(0.1)) +
	xlab("Runtime") +
	ylab("Size (Kb)") +
	ggtitle("Average memory footprint", subtitle="per container") +
	ylim(0, NA) +
	theme(axis.text.x=element_text(angle=90))

bar_plot <- ggplot() +
	geom_col( data=data, aes(runtime, read_bw_kps, colour='red')) +
	geom_col( data=data, aes(runtime, write_bw_kps, colour='green')) +
	xlab("Runtime") +
	ylab("bandwidth (K/s)") +
	ggtitle("Storage bandwidth") +
	ylim(0, NA) +
	theme(axis.text.x=element_text(angle=90))
}

read_box_plot <- ggplot() +
	geom_boxplot( data=data, aes(blocksize, read_bw_kps, color=runtime)) +
	ylim(0, NA) +
	ggtitle("Read bandwidth") +
	xlab("Runtime") +
	ylab("BW (K/s)") +
	theme(axis.text.x=element_text(angle=90))

write_box_plot <- ggplot() +
	geom_boxplot( data=data, aes(blocksize, write_bw_kps, color=runtime), show.legend=FALSE) +
	ylim(0, NA) +
	ggtitle("Write bandwidth") +
	xlab("Runtime") +
	ylab("BW (K/s)") +
	theme(axis.text.x=element_text(angle=90))

master_plot = grid.arrange(
	read_box_plot,
	write_box_plot,
	nrow=1,
	ncol=2 )

print(master_plot)

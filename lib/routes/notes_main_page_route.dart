import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:potato_notes/internal/app_info.dart';
import 'package:potato_notes/internal/localizations.dart';
import 'package:potato_notes/internal/methods.dart';
import 'package:potato_notes/internal/note_helper.dart';
import 'package:potato_notes/internal/search_filters.dart';
import 'package:potato_notes/routes/modify_notes_route.dart';
import 'package:potato_notes/routes/search_notes_route.dart';
import 'package:potato_notes/routes/security_note_route.dart';
import 'package:potato_notes/routes/settings_route.dart';
import 'package:provider/provider.dart';
import 'package:share/share.dart';

class NotesMainPageRoute extends StatefulWidget {
  final List<Note> noteList;

  NotesMainPageRoute({@required this.noteList});

  @override
  _NotesMainPageState createState() => new _NotesMainPageState(noteList);
}

class _NotesMainPageState extends State<NotesMainPageRoute> {
  List<Note> noteList = List<Note>();

  _NotesMainPageState(List<Note> list) {
    this.noteList = list;
  }

  static GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey<ScaffoldState>();

  List<int> selectionList = List<int>();
  bool isSelectorVisible = false;

  AppInfoProvider appInfo;
  AppLocalizations locales;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher_fg');
      IOSInitializationSettings initializationSettingsIOS =
          IOSInitializationSettings();
      InitializationSettings initializationSettings =
          new InitializationSettings(
              initializationSettingsAndroid, initializationSettingsIOS);

      Future onNotificationClicked(String payload) async {
        List<String> payloadSplitted = payload.split(":");
        bool executeAlt = true;
        try {
          String _ = payloadSplitted[1];
        } on RangeError {
          executeAlt = false;
        }

        if (executeAlt) {
          appInfo.remindersNotifIdList.remove(payloadSplitted[0]);
          List<int> noteListId = List<int>();
          noteList.forEach((item) {
            noteListId.add(item.id);
          });
          Note note =
              noteList[noteListId.indexOf(int.parse(payloadSplitted[0]))];
          List<String> remindersString = note.reminders.split(":");
          remindersString.remove(payloadSplitted[1]);
          _editNoteCaller(
              context,
              Note(
                  id: int.parse(payloadSplitted[0]),
                  title: note.title,
                  content: note.content,
                  isStarred: note.isStarred,
                  date: note.date,
                  color: note.color,
                  imagePath: note.imagePath,
                  isList: note.isList,
                  listParseString: note.listParseString,
                  reminders: remindersString.join(":")));
        } else {
          appInfo.notificationsIdList.remove(payloadSplitted[0]);
        }
      }

      flutterLocalNotificationsPlugin.initialize(initializationSettings,
          onSelectNotification: onNotificationClicked);

      initializeNotifications();
    });
  }

  void initializeNotifications() async {
    final appInfo = Provider.of<AppInfoProvider>(context);

    for (int i = 0; i < appInfo.notificationsIdList.length; i++) {
      int index = int.parse(appInfo.notificationsIdList[i]);
      await FlutterLocalNotificationsPlugin().show(
          index,
          noteList[index].title != ""
              ? noteList[index].title
              : locales.notesMainPageRoute_pinnedNote,
          noteList[index].content,
          NotificationDetails(
              AndroidNotificationDetails(
                '0',
                'note_pinned_notifications',
                'idk',
                priority: Priority.High,
                playSound: true,
                importance: Importance.High,
                ongoing: true,
              ),
              IOSNotificationDetails()),
          payload: index.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    appInfo = Provider.of<AppInfoProvider>(context);
    locales = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      key: scaffoldKey,
      body: Stack(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Container(
              padding:
                  EdgeInsets.only(left: isSelectorVisible ? 10 : 20, right: 10),
              height: 70,
              child: isSelectorVisible
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Center(
                          child: IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () async {
                              selectionList = List<int>();
                              noteList.forEach((item) {
                                item.isSelected = false;
                              });
                              setState(() => isSelectorVisible = false);
                            },
                          ),
                        ),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Text(
                              selectionList.length.toString(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Spacer(),
                        Center(
                          child: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () async {
                              for (int i = 0; i < selectionList.length; i++)
                                await NoteHelper().delete(selectionList[i]);
                              selectionList = List<int>();
                              List<Note> list = await NoteHelper().getNotes();
                              setState(() {
                                noteList = list;
                                isSelectorVisible = false;
                              });
                            },
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        Center(
                          child: Text(
                            locales.notes,
                            style: TextStyle(
                              fontSize: 26.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.select_all),
                          onPressed: () {
                            setState(() => isSelectorVisible = true);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.search),
                          onPressed: () => _searchNoteCaller(context, noteList),
                        ),
                        IconButton(
                          iconSize: 24.0,
                          onPressed: () =>
                              showUserSettingsScrollableBottomSheet(context),
                          icon: CircleAvatar(
                            backgroundColor: appInfo.mainColor,
                            child: appInfo.userImagePath == null
                                ? Icon(
                                    Icons.account_circle,
                                    color: Colors.white,
                                    size: 28.0,
                                  )
                                : null,
                            backgroundImage: appInfo.userImagePath == null
                                ? null
                                : FileImage(File(appInfo.userImagePath)),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Padding(
            padding:
                EdgeInsets.only(top: MediaQuery.of(context).padding.top + 70),
            child: noteList.length == 0
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.close,
                            size: 50.0,
                            color: HSLColor.fromColor(
                                    Theme.of(context).textTheme.title.color)
                                .withAlpha(0.4)
                                .toColor()),
                        Text(
                          locales.notesMainPageRoute_noNotes,
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.w500,
                            color: HSLColor.fromColor(
                                    Theme.of(context).textTheme.title.color)
                                .withAlpha(0.4)
                                .toColor(),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    children: noteListBuilder(context),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).accentColor,
        elevation: 0.0,
        onPressed: () {
          _addNoteCaller(context);
          selectionList = List<int>();
          noteList.forEach((item) {
            item.isSelected = false;
          });
          setState(() => isSelectorVisible = false);
        },
        child: Icon(Icons.edit),
        tooltip: locales.notesMainPageRoute_addButtonTooltip,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _bottomBar,
    );
  }

  List<Widget> noteListBuilder(BuildContext context) {
    final appInfo = Provider.of<AppInfoProvider>(context);

    if (!appInfo.isGridView) {
      List<Widget> pinnedNotes = List<Widget>();
      List<Widget> normalNotes = List<Widget>();

      pinnedNotes.add(
        Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.star,
                  size: 12.0,
                  color: HSLColor.fromColor(
                          Theme.of(context).textTheme.title.color)
                      .withAlpha(0.4)
                      .toColor(),
                ),
                Text(
                  "  " + locales.notesMainPageRoute_starred,
                  style: TextStyle(
                      fontSize: 14.0,
                      color: HSLColor.fromColor(
                              Theme.of(context).textTheme.title.color)
                          .withAlpha(0.4)
                          .toColor()),
                ),
              ],
            )),
      );

      for (int i = 0; i < noteList.length; i++) {
        int bIndex = (noteList.length - 1) - i;
        if (noteList[bIndex].isStarred == 1) {
          pinnedNotes.add(noteListItem(context, bIndex, false));
        }
      }

      for (int i = 0; i < noteList.length; i++) {
        int bIndex = (noteList.length - 1) - i;
        if (noteList[bIndex].isStarred == 0) {
          normalNotes.add(noteListItem(context, bIndex, false));
        }
      }

      pinnedNotes.add(
        Container(
          width: MediaQuery.of(context).size.width,
          padding: EdgeInsets.only(top: 10, bottom: 10, left: 100, right: 100),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(20)),
              color: HSLColor.fromColor(Theme.of(context).textTheme.title.color)
                  .withAlpha(0.2)
                  .toColor(),
            ),
            width: MediaQuery.of(context).size.width - 200,
            height: 2,
          ),
        ),
      );

      return <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            pinnedNotes.length > 2
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: pinnedNotes,
                  )
                : Container(),
            normalNotes.length > 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: normalNotes,
                  )
                : Container(),
          ],
        ),
      ];
    } else {
      List<int> pinnedIndexes = List<int>();
      List<int> normalIndexes = List<int>();
      List<Widget> pinnedWidgets = List<Widget>();
      List<Widget> normalWidgets = List<Widget>();

      pinnedWidgets.add(
        Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.star,
                  size: 12.0,
                  color: HSLColor.fromColor(
                          Theme.of(context).textTheme.title.color)
                      .withAlpha(0.4)
                      .toColor(),
                ),
                Text(
                  "  " + locales.notesMainPageRoute_starred,
                  style: TextStyle(
                      fontSize: 14.0,
                      color: HSLColor.fromColor(
                              Theme.of(context).textTheme.title.color)
                          .withAlpha(0.4)
                          .toColor()),
                ),
              ],
            )),
      );

      for (int i = 0; i < noteList.length; i++) {
        if (noteList[i].isStarred == 1) {
          pinnedIndexes.add(i);
        }
      }

      for (int i = 0; i < noteList.length; i++) {
        if (noteList[i].isStarred == 0) {
          normalIndexes.add(i);
        }
      }

      Widget pinnedGrid = noteGridBuilder(context, pinnedIndexes);
      Widget normalGrid = noteGridBuilder(context, normalIndexes);

      if (pinnedGrid != null) pinnedWidgets.add(pinnedGrid);

      if (normalGrid != null) normalWidgets.add(normalGrid);

      pinnedWidgets.add(
        Container(
          width: MediaQuery.of(context).size.width,
          padding: EdgeInsets.only(top: 10, bottom: 10, left: 100, right: 100),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(20)),
              color: HSLColor.fromColor(Theme.of(context).textTheme.title.color)
                  .withAlpha(0.2)
                  .toColor(),
            ),
            width: MediaQuery.of(context).size.width - 200,
            height: 2,
          ),
        ),
      );

      return <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            pinnedWidgets.length > 2
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: pinnedWidgets,
                  )
                : Container(),
            normalWidgets.length > 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: normalWidgets,
                  )
                : Container(),
          ],
        ),
      ];
    }
  }

  Widget noteGridBuilder(BuildContext context, List<int> indexes) {
    List<Widget> columnOne = List<Widget>();
    List<Widget> columnTwo = List<Widget>();

    bool secondColumnFirst = false;

    if ((indexes.length - 1).isEven) {
      secondColumnFirst = false;
    } else {
      secondColumnFirst = true;
    }

    for (int i = 0; i < indexes.length; i++) {
      int bIndex = (indexes.length - 1) - i;
      if (bIndex.isEven) {
        columnOne.add(noteListItem(context, indexes[bIndex], true));
      } else {
        columnTwo.add(noteListItem(context, indexes[bIndex], true));
      }
    }

    if (indexes.length > 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: MediaQuery.of(context).size.width / 2 - 20,
            child: Column(
              children: secondColumnFirst ? columnTwo : columnOne,
            ),
          ),
          Container(
            width: MediaQuery.of(context).size.width / 2 - 20,
            child: Column(
              children: secondColumnFirst ? columnOne : columnTwo,
            ),
          ),
        ],
      );
    } else
      return null;
  }

  void _addNoteCaller(BuildContext context) async {
    final Note emptyNote = Note(
      id: null,
      title: "",
      content: "",
      isStarred: 0,
      date: 0,
      color: null,
      imagePath: null,
      isList: 0,
      listParseString: null,
      reminders: null,
      hideContent: 0,
      pin: null,
      password: null,
    );
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ModifyNotesRoute(note: emptyNote)));

    if (result != null) setState(() => noteList = result);

    Brightness systemBarsIconBrightness =
        Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark;

    changeSystemBarsColors(
        Theme.of(context).scaffoldBackgroundColor, systemBarsIconBrightness);
  }

  void _editNoteCaller(BuildContext context, Note note) async {
    if (note.hideContent == 1 && (note.pin != null || note.password != null)) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => SecurityNoteRoute(note: note)));
    } else {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ModifyNotesRoute(note: note)));
    }

    List<Note> list = await NoteHelper().getNotes();

    setState(() => noteList = list);

    Brightness systemBarsIconBrightness =
        Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark;

    changeSystemBarsColors(
        Theme.of(context).scaffoldBackgroundColor, systemBarsIconBrightness);
  }

  void _searchNoteCaller(BuildContext context, List<Note> noteList) async {
    SearchFiltersProvider searchFilters =
        Provider.of<SearchFiltersProvider>(context);

    searchFilters.color = null;
    searchFilters.date = null;
    searchFilters.caseSensitive = false;

    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => SearchNotesRoute(noteList: noteList)));

    if (result != null) setState(() => noteList = result);

    Brightness systemBarsIconBrightness =
        Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark;

    changeSystemBarsColors(
        Theme.of(context).scaffoldBackgroundColor, systemBarsIconBrightness);
  }

  void _settingsCaller(BuildContext context) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (context) => SettingsRoute()));

    List<Note> list = await NoteHelper().getNotes();
    setState(() => noteList = list);

    Brightness systemBarsIconBrightness =
        Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark;

    changeSystemBarsColors(
        Theme.of(context).scaffoldBackgroundColor, systemBarsIconBrightness);
  }

  Widget noteListItem(BuildContext context, int index, bool oneSideOnly) {
    final appInfo = Provider.of<AppInfoProvider>(context);

    double getAlphaFromTheme() {
      if (Theme.of(context).brightness == Brightness.light) {
        return 0.1;
      } else {
        return 0.2;
      }
    }

    Color cardColor = Theme.of(context).textTheme.title.color;

    double cardBrightness = getAlphaFromTheme();

    Color borderColor =
        HSLColor.fromColor(cardColor).withAlpha(cardBrightness).toColor();

    Color getTextColorFromNoteColor(int index, bool isContent) {
      double noteColorBrightness =
          Color(noteList[index].color).computeLuminance();
      Color contentWhite =
          HSLColor.fromColor(Colors.white).withAlpha(0.7).toColor();
      Color contentBlack =
          HSLColor.fromColor(Colors.black).withAlpha(0.7).toColor();

      if (noteColorBrightness > 0.5) {
        return isContent ? contentBlack : Colors.black;
      } else {
        return isContent ? contentWhite : Colors.white;
      }
    }

    return GestureDetector(
      onTap: () {
        if (isSelectorVisible) {
          setState(() {
            noteList[index].isSelected = !noteList[index].isSelected;
            if (noteList[index].isSelected) {
              selectionList.add(noteList[index].id);
            } else {
              selectionList.remove(noteList[index].id);
              if (selectionList.length == 0) {
                isSelectorVisible = false;
              }
            }
          });
        } else {
          _editNoteCaller(context, noteList[index]);
        }
      },
      onDoubleTap: isSelectorVisible
          ? null
          : appInfo.isQuickStarredGestureOn
              ? () => toggleStarNote(index)
              : null,
      onLongPress: () {
        if (!isSelectorVisible)
          showNoteSettingsScrollableBottomSheet(context, index);
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
              color: noteList[index].isSelected
                  ? noteList[index].color != null
                      ? Theme.of(context).textTheme.title.color
                      : Theme.of(context).accentColor
                  : noteList[index].color != null
                      ? Colors.transparent
                      : borderColor,
              width: 1.5),
        ),
        color: noteList[index].color == null
            ? Theme.of(context).cardColor
            : Color(noteList[index].color),
        child: Padding(
            padding: EdgeInsets.symmetric(vertical: 0, horizontal: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                Visibility(
                  visible: noteList[index].imagePath != null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12)),
                    child: noteList[index].imagePath == null
                        ? Container()
                        : Image(
                            image: FileImage(File(noteList[index].imagePath)),
                            fit: BoxFit.fitWidth,
                            width: oneSideOnly
                                ? MediaQuery.of(context).size.width / 2
                                : MediaQuery.of(context).size.width,
                          ),
                  ),
                ),
                Visibility(
                  visible: noteList[index].hideContent == 1 ||
                      noteList[index].reminders != null,
                  child: Container(
                    margin: EdgeInsets.fromLTRB(
                        20,
                        14,
                        20,
                        noteList[index].hideContent == 1 &&
                                noteList[index].title == ""
                            ? 14
                            : 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Visibility(
                          visible: noteList[index].reminders != null,
                          child: Center(
                            child: Icon(
                              Icons.alarm,
                              size: 12,
                              color: noteList[index].color == null
                                  ? null
                                  : getTextColorFromNoteColor(index, false),
                            ),
                          ),
                        ),
                        Visibility(
                          visible: noteList[index].hideContent == 1,
                          child: Center(
                            child: Icon(
                              noteList[index].pin != null ||
                                      noteList[index].password != null
                                  ? Icons.lock
                                  : Icons.remove_red_eye,
                              size: 12,
                              color: noteList[index].color == null
                                  ? null
                                  : getTextColorFromNoteColor(index, false),
                            ),
                          ),
                        ),
                        Visibility(
                          visible: (noteList[index].hideContent == 1 &&
                                  noteList[index].reminders == null) ||
                              (noteList[index].hideContent == 0 &&
                                  noteList[index].reminders != null),
                          child: Container(
                            padding: EdgeInsets.only(left: 8),
                            width: oneSideOnly
                                ? MediaQuery.of(context).size.width / 2 - 80
                                : MediaQuery.of(context).size.width - 100,
                            child: (noteList[index].hideContent == 1 &&
                                    noteList[index].reminders == null)
                                ? Text(
                                    locales
                                        .notesMainPageRoute_note_hiddenContent,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: noteList[index].color == null
                                          ? null
                                          : getTextColorFromNoteColor(
                                              index, false),
                                    ),
                                  )
                                : (noteList[index].hideContent == 0 &&
                                        noteList[index].reminders != null)
                                    ? Text(
                                        locales
                                            .notesMainPageRoute_note_remindersSet,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: noteList[index].color == null
                                              ? null
                                              : getTextColorFromNoteColor(
                                                  index, false),
                                        ),
                                      )
                                    : Container(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Visibility(
                  visible: appInfo.devShowIdLabels,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Text(
                      "Note id: " + noteList[index].id.toString(),
                      style: TextStyle(
                        color: noteList[index].color == null
                            ? null
                            : getTextColorFromNoteColor(index, false),
                      ),
                    ),
                  ),
                ),
                Visibility(
                  visible: noteList[index].title != "",
                  child: Container(
                    margin: EdgeInsets.fromLTRB(20, 14, 20, 0),
                    width: oneSideOnly
                        ? MediaQuery.of(context).size.width / 2
                        : MediaQuery.of(context).size.width,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        noteList[index].title,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 4,
                        style: TextStyle(
                          color: noteList[index].color == null
                              ? null
                              : getTextColorFromNoteColor(index, false),
                          fontSize: 18.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                Visibility(
                  visible: noteList[index].hideContent == 0,
                  child: Container(
                    margin: EdgeInsets.fromLTRB(
                        20, noteList[index].title == "" ? 14 : 0, 20, 14),
                    width: oneSideOnly
                        ? MediaQuery.of(context).size.width / 2
                        : MediaQuery.of(context).size.width,
                    child: noteList[index].isList == 1
                        ? Column(
                            children: generateListWidgets(index, oneSideOnly),
                          )
                        : Text(
                            noteList[index].content,
                            overflow: TextOverflow.ellipsis,
                            textWidthBasis: TextWidthBasis.parent,
                            maxLines: 11,
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w400,
                              color: noteList[index].color == null
                                  ? Theme.of(context).textTheme.title.color
                                  : getTextColorFromNoteColor(index, true),
                            ),
                          ),
                  ),
                ),
              ],
            )),
      ),
    );
  }

  List<Widget> generateListWidgets(int index, bool oneSideOnly) {
    List<Widget> widgets = List<Widget>();
    List<ListPair> checkedList = List<ListPair>();
    List<ListPair> uncheckedList = List<ListPair>();

    Color getTextColorFromNoteColor(int index, bool isContent) {
      double noteColorBrightness =
          Color(noteList[index].color).computeLuminance();
      Color contentWhite =
          HSLColor.fromColor(Colors.white).withAlpha(0.7).toColor();
      Color contentBlack =
          HSLColor.fromColor(Colors.black).withAlpha(0.7).toColor();

      if (noteColorBrightness > 0.5) {
        return isContent ? contentBlack : Colors.black;
      } else {
        return isContent ? contentWhite : Colors.white;
      }
    }

    List<String> rawList = noteList[index].listParseString.split("\'..\'");

    for (int i = 0; i < rawList.length; i++) {
      List<dynamic> rawStrings = rawList[i].split("\',,\'");

      int checkValue = rawStrings[0] == "" ? 0 : int.parse(rawStrings[0]);

      if (checkValue == 1) {
        try {
          checkedList
              .add(ListPair(checkValue: checkValue, title: rawStrings[1]));
        } on RangeError {}
      } else {
        try {
          uncheckedList
              .add(ListPair(checkValue: checkValue, title: rawStrings[1]));
        } on RangeError {}
      }
    }

    for (int i = 0; i < uncheckedList.length; i++) {
      widgets.add(Row(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Icon(Icons.check_box_outline_blank,
              size: 14,
              color: noteList[index].color == null
                  ? Theme.of(context).iconTheme.color
                  : getTextColorFromNoteColor(index, true)),
          Container(
            padding: EdgeInsets.only(left: 6, top: 4, bottom: 4),
            width: oneSideOnly
                ? MediaQuery.of(context).size.width / 2 - 88
                : MediaQuery.of(context).size.width - 108,
            child: Text(
              uncheckedList[i].title,
              overflow: TextOverflow.ellipsis,
              textWidthBasis: TextWidthBasis.parent,
              style: TextStyle(
                  color: noteList[index].color == null
                      ? Theme.of(context).textTheme.title.color
                      : getTextColorFromNoteColor(index, true)),
            ),
          )
        ],
      ));
    }

    if (checkedList.length != 0) {
      widgets.add(Row(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Icon(Icons.add,
              size: 14,
              color: noteList[index].color == null
                  ? Theme.of(context).iconTheme.color
                  : getTextColorFromNoteColor(index, true)),
          Container(
            width: oneSideOnly
                ? MediaQuery.of(context).size.width / 2 - 88
                : MediaQuery.of(context).size.width - 108,
            padding: EdgeInsets.only(left: 6, top: 4, bottom: 4),
            child: Text(
              checkedList.length.toString() +
                  locales.notesMainPageRoute_note_list_selectedEntries,
              style: TextStyle(
                  color: noteList[index].color == null
                      ? Theme.of(context).textTheme.title.color
                      : getTextColorFromNoteColor(index, true)),
            ),
          )
        ],
      ));
    }

    return widgets;
  }

  Widget get _bottomBar {
    final appInfo = Provider.of<AppInfoProvider>(context);

    return ClipRRect(
      borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.0), topRight: Radius.circular(16.0)),
      child: Builder(builder: (context) {
        return BottomAppBar(
          color: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          shape: CircularNotchedRectangle(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: <Widget>[
                Spacer(),
                IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: () {
                    _settingsCaller(context);
                  },
                ),
                Spacer(flex: 3),
                IconButton(
                  icon: appInfo.isGridView
                      ? Icon(Icons.list)
                      : Icon(Icons.grid_on),
                  onPressed: () {
                    appInfo.isGridView = !appInfo.isGridView;
                  },
                ),
                Spacer(),
              ],
            ),
          ),
        );
      }),
    );
  }

  void toggleStarNote(int index) async {
    if (noteList[index].isStarred == 0) {
      await NoteHelper().update(
        noteList[index].copyWith(localIsStarred: 1),
      );
      List<Note> list = await NoteHelper().getNotes();
      setState(() => noteList = list);
    } else if (noteList[index].isStarred == 1) {
      await NoteHelper().update(
        noteList[index].copyWith(localIsStarred: 0),
      );
      List<Note> list = await NoteHelper().getNotes();
      setState(() => noteList = list);
    }
  }

  void showUserSettingsScrollableBottomSheet(BuildContext context) {
    final appInfo = Provider.of<AppInfoProvider>(context);

    showModalBottomSheet<void>(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        context: context,
        builder: (BuildContext context) {
          TextEditingController userNameController =
              TextEditingController(text: appInfo.userName);

          return Stack(
            children: <Widget>[
              Positioned(
                top: 0,
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      locales.notesMainPageRoute_user_info,
                      style: TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 68),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: InkWell(
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                image: appInfo.userImagePath == null
                                    ? null
                                    : DecorationImage(
                                        fit: BoxFit.cover,
                                        image: FileImage(
                                            File(appInfo.userImagePath)),
                                      ),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(150)),
                                color: appInfo.mainColor,
                              ),
                              child: appInfo.userImagePath == null
                                  ? Center(
                                      child: Icon(
                                        Icons.account_circle,
                                        size: 145,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          onTap: () async {
                            showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: Text(locales.chooseAction),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(8.0))),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        ListTile(
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 0),
                                          leading: Icon(Icons.photo_library),
                                          title: Text(locales
                                              .notesMainPageRoute_user_avatar_change),
                                          onTap: () async {
                                            Navigator.pop(context);
                                            File image =
                                                await ImagePicker.pickImage(
                                                    source:
                                                        ImageSource.gallery);
                                            if (image != null)
                                              appInfo.userImagePath =
                                                  image.path;
                                          },
                                        ),
                                        ListTile(
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 0),
                                          leading: Icon(Icons.delete),
                                          title: Text(locales
                                              .notesMainPageRoute_user_avatar_remove),
                                          onTap: () async {
                                            appInfo.userImagePath = null;
                                            Navigator.pop(context);
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                });
                          },
                          borderRadius: BorderRadius.all(Radius.circular(150)),
                        ),
                      ),
                      Center(
                        child: InkWell(
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 18, vertical: 24),
                            child: Text(
                              appInfo.userName == ""
                                  ? "User"
                                  : appInfo.userName,
                              style: TextStyle(
                                fontSize: 24.0,
                              ),
                            ),
                          ),
                          onTap: () => showDialog(
                            context: context,
                            builder: (context) {
                              double getAlphaFromTheme() {
                                switch (appInfo.themeMode) {
                                  case 0:
                                    return 0.1;
                                  case 1:
                                    return 0.2;
                                  case 2:
                                    return 0.3;
                                  default:
                                    return 0;
                                }
                              }

                              String currentName = appInfo.userName;
                              Color cardColor =
                                  Theme.of(context).textTheme.title.color;

                              double cardBrightness = getAlphaFromTheme();

                              Color borderColor = HSLColor.fromColor(cardColor)
                                  .withAlpha(cardBrightness)
                                  .toColor();
                              return AlertDialog(
                                title: Text(locales
                                    .notesMainPageRoute_user_name_change),
                                contentPadding:
                                    EdgeInsets.fromLTRB(12, 12, 12, 0),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(8.0))),
                                content: Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      side: BorderSide(
                                          color: borderColor, width: 1.5),
                                    ),
                                    color: Theme.of(context).cardColor,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 2),
                                      child: TextField(
                                        controller: userNameController,
                                        onChanged: (value) =>
                                            currentName = value,
                                        maxLines: 1,
                                        decoration: InputDecoration(
                                            border: InputBorder.none,
                                            hintText: "User"),
                                      ),
                                    )),
                                actions: <Widget>[
                                  FlatButton(
                                    child: Text(locales.cancel),
                                    onPressed: () => Navigator.pop(context),
                                    textColor: appInfo.mainColor,
                                    hoverColor: appInfo.mainColor,
                                  ),
                                  FlatButton(
                                    child: Text(locales.reset),
                                    onPressed: () {
                                      appInfo.userName = "";
                                      Navigator.pop(context);
                                    },
                                    textColor: appInfo.mainColor,
                                    hoverColor: appInfo.mainColor,
                                  ),
                                  FlatButton(
                                    child: Text(locales.done),
                                    onPressed: () {
                                      appInfo.userName = currentName;
                                      Navigator.pop(context);
                                    },
                                    textColor: appInfo.mainColor,
                                    hoverColor: appInfo.mainColor,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        });
  }

  void showNoteSettingsScrollableBottomSheet(BuildContext context, int index) {
    final appInfo = Provider.of<AppInfoProvider>(context);
    BuildContext parentContext = context;
    Note curNote = noteList[index];
    showModalBottomSheet<void>(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        context: context,
        builder: (BuildContext context) {
          bool noteStarred = curNote.isStarred == 1;
          bool indexExists = true;

          return !indexExists
              ? Container()
              : SingleChildScrollView(
                  padding: EdgeInsets.only(top: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ListTile(
                        leading: Icon(Icons.check),
                        title: Text(locales.note_select),
                        onTap: () {
                          setState(() {
                            isSelectorVisible = true;
                            curNote.isSelected = true;
                            selectionList.add(curNote.id);
                          });
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.edit),
                        title: Text(locales.note_edit),
                        onTap: () {
                          Navigator.pop(context);
                          _editNoteCaller(parentContext, curNote);
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.delete),
                        title: Text(locales.note_delete),
                        onTap: () async {
                          Navigator.pop(context);
                          Note noteBackup = curNote;
                          await NoteHelper().delete(curNote.id);
                          List<Note> list = await NoteHelper().getNotes();
                          setState(() => noteList = list);
                          scaffoldKey.currentState.removeCurrentSnackBar();
                          scaffoldKey.currentState.showSnackBar(
                            SnackBar(
                              content: Text(locales.note_delete_snackbar),
                              behavior: SnackBarBehavior.floating,
                              elevation: 0.0,
                              action: SnackBarAction(
                                label: locales.undo,
                                onPressed: () async {
                                  await NoteHelper().insert(noteBackup);
                                  List<Note> list =
                                      await NoteHelper().getNotes();
                                  setState(() => noteList = list);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading:
                            Icon(noteStarred ? Icons.star : Icons.star_border),
                        title: Text(noteStarred
                            ? locales.note_unstar
                            : locales.note_star),
                        onTap: () async {
                          if (noteStarred) {
                            await NoteHelper().update(
                              curNote.copyWith(localIsStarred: 0),
                            );
                            List<Note> list = await NoteHelper().getNotes();
                            setState(() => noteList = list);
                          } else {
                            await NoteHelper().update(
                              curNote.copyWith(localIsStarred: 1),
                            );
                            List<Note> list = await NoteHelper().getNotes();
                            setState(() => noteList = list);
                          }
                          Navigator.pop(context);
                        },
                      ),
                      Divider(),
                      Visibility(
                        visible: curNote.hideContent == 1 &&
                            (curNote.pin != null || curNote.password != null),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 22, vertical: 10),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.lock,
                                size: 14,
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  locales.note_lockedOptions,
                                  style: TextStyle(fontSize: 12),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                      Visibility(
                        visible: curNote.isList == 0 &&
                            !(curNote.hideContent == 1 &&
                                (curNote.pin != null ||
                                    curNote.password != null)),
                        child: Column(
                          children: <Widget>[
                            ListTile(
                              leading: Icon(Icons.share),
                              title: Text(locales.note_share),
                              onTap: () {
                                String shareText = "";

                                if (curNote.title != "")
                                  shareText += curNote.title + "\n\n";
                                shareText += curNote.content;

                                Share.share(shareText);
                                Navigator.pop(context);
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.file_upload),
                              title: Text(locales.note_export),
                              onTap: () async {
                                if (appInfo.storageStatus ==
                                    PermissionStatus.granted) {
                                  DateTime now = DateTime.now();

                                  bool backupDirExists = await Directory(
                                          '/storage/emulated/0/PotatoNotes/exported')
                                      .exists();

                                  if (!backupDirExists) {
                                    await Directory(
                                            '/storage/emulated/0/PotatoNotes/exported')
                                        .create(recursive: true);
                                  }

                                  String noteExportPath =
                                      '/storage/emulated/0/PotatoNotes/exported/exported_note_' +
                                          DateFormat("dd-MM-yyyy_HH-mm")
                                              .format(now) +
                                          '.md';

                                  String noteContents = "";

                                  if (curNote.title != "")
                                    noteContents +=
                                        "# " + curNote.title + "\n\n";

                                  noteContents += curNote.content;

                                  Navigator.pop(context);

                                  File(noteExportPath)
                                      .writeAsString(noteContents)
                                      .then((nothing) {
                                    scaffoldKey.currentState
                                        .showSnackBar(SnackBar(
                                      content: Text(locales
                                              .note_exportLocation +
                                          " PotatoNotes/exported/exported_note_" +
                                          DateFormat("dd-MM-yyyy_HH-mm-ss")
                                              .format(now)),
                                    ));
                                  });
                                } else {
                                  await PermissionHandler().requestPermissions(
                                      [PermissionGroup.storage]);
                                  appInfo.storageStatus =
                                      await PermissionHandler()
                                          .checkPermissionStatus(
                                              PermissionGroup.storage);
                                }
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.notifications),
                              enabled: !appInfo.notificationsIdList
                                  .contains(index.toString()),
                              title: Text(locales.note_pinToNotifs),
                              onTap: () async {
                                appInfo.notificationsIdList
                                    .add(index.toString());
                                await FlutterLocalNotificationsPlugin().show(
                                    int.parse(appInfo.notificationsIdList.last),
                                    curNote.title != ""
                                        ? curNote.title
                                        : "Pinned note",
                                    curNote.content,
                                    NotificationDetails(
                                        AndroidNotificationDetails(
                                          '0',
                                          'note_pinned_notifications',
                                          'idk',
                                          priority: Priority.High,
                                          playSound: true,
                                          importance: Importance.High,
                                          ongoing: true,
                                        ),
                                        IOSNotificationDetails()),
                                    payload: index.toString());
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                );
        });
  }
}
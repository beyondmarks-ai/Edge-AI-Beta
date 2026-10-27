import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/edge_models.dart';
import '../services/edge_repository.dart';
import 'offline_chat_screen.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    required this.repository,
    required this.sessionId,
    this.active = true,
  });
  final EdgeRepository repository;
  final String sessionId;
  final bool active;

  @override
  State<AssistantScreen> createState() => _AssistantModeState();
}

class _AssistantModeState extends State<AssistantScreen> {
  bool offline = true;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: true,
              icon: Icon(Icons.offline_bolt_outlined),
              label: Text('Offline'),
            ),
            ButtonSegment(
              value: false,
              icon: Icon(Icons.cloud_outlined),
              label: Text('Cloud'),
            ),
          ],
          selected: {offline},
          onSelectionChanged: (value) => setState(() => offline = value.first),
        ),
      ),
      Expanded(
        child: offline
            ? widget.active
                  ? const OfflineChatScreen()
                  : const SizedBox.shrink()
            : _CloudAssistantScreen(
                repository: widget.repository,
                sessionId: widget.sessionId,
              ),
      ),
    ],
  );
}

class _CloudAssistantScreen extends StatefulWidget {
  const _CloudAssistantScreen({
    required this.repository,
    required this.sessionId,
  });
  final EdgeRepository repository;
  final String sessionId;

  @override
  State<_CloudAssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<_CloudAssistantScreen> {
  static const suggestions = [
    'What is Rakesh wearing?',
    'Where is Rakesh now?',
    'Who is carrying an object?',
    'Who left and returned today?',
  ];
  final input = TextEditingController();
  final scrollController = ScrollController();
  final messages = <AssistantMessage>[];
  String? conversationId;
  RagDocument? selectedDocument;
  bool loading = false;

  @override
  void dispose() {
    input.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> send() async {
    final question = input.text.trim();
    if (question.isEmpty || loading) return;
    setState(() {
      loading = true;
      messages.add(
        AssistantMessage(
          role: 'USER',
          text: question,
          timestamp: DateTime.now(),
        ),
      );
      input.clear();
    });
    _scrollToLatest();
    try {
      final reply = await widget.repository.askAssistant(
        question,
        sessionId: widget.sessionId,
        conversationId: conversationId,
        documentId: selectedDocument?.id,
      );
      if (!mounted) return;
      setState(() {
        conversationId = reply.conversationId;
        messages.add(
          AssistantMessage(
            role: 'ASSISTANT',
            text: reply.answer,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToLatest();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => messages.add(
          AssistantMessage(
            role: 'ASSISTANT',
            text: 'Assistant error: $e',
            timestamp: DateTime.now(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void ask(String question) {
    input.text = question;
    send();
  }

  void newChat() {
    if (loading) return;
    setState(() {
      conversationId = null;
      messages.clear();
      input.clear();
    });
  }

  void selectDocument(RagDocument document) {
    setState(() {
      selectedDocument = document;
      conversationId = null;
      messages.clear();
      input.clear();
    });
  }

  void clearDocument() {
    if (loading) return;
    setState(() {
      selectedDocument = null;
      conversationId = null;
      messages.clear();
      input.clear();
    });
  }

  Future<void> uploadPdf() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (picked.isEmpty || picked.single.path == null || !mounted) return;
    final platformFile = picked.single;
    setState(() => loading = true);
    try {
      var document = await widget.repository.uploadDocument(
        File(platformFile.path!),
        platformFile.name,
      );
      for (
        var attempt = 0;
        attempt < 40 && document.status == 'PROCESSING';
        attempt++
      ) {
        await Future<void>.delayed(const Duration(seconds: 3));
        final documents = await widget.repository.documents();
        document = documents.firstWhere(
          (item) => item.id == document.id,
          orElse: () => document,
        );
      }
      if (!mounted) return;
      if (document.isReady) {
        selectDocument(document);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${document.fileName} is ready for questions.'),
          ),
        );
      } else if (document.status == 'FAILED') {
        throw Exception(document.error ?? 'PDF processing failed.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'PDF is still processing. Open Documents to refresh.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not upload PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> showDocuments() async {
    if (loading) return;
    try {
      final documents = await widget.repository.documents();
      if (!mounted) return;
      final selected = await showModalBottomSheet<Object>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                leading: Icon(Icons.picture_as_pdf_outlined),
                title: Text('PDF knowledge'),
                subtitle: Text('Private AWS RAG documents'),
              ),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Upload PDF'),
                subtitle: const Text('Maximum 15 MB'),
                onTap: () => Navigator.pop(context, 'upload'),
              ),
              const Divider(height: 1),
              if (documents.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No PDFs uploaded yet.'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: documents.length,
                    itemBuilder: (_, index) {
                      final document = documents[index];
                      return ListTile(
                        enabled: document.isReady,
                        leading: Icon(
                          document.isReady
                              ? Icons.description
                              : Icons.pending_outlined,
                        ),
                        title: Text(
                          document.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          document.isReady
                              ? '${document.pageCount ?? 0} pages • ${document.chunkCount ?? 0} searchable sections'
                              : document.status.toLowerCase(),
                        ),
                        trailing: selectedDocument?.id == document.id
                            ? const Icon(Icons.check_circle)
                            : const Icon(Icons.chevron_right),
                        onTap: document.isReady
                            ? () => Navigator.pop(context, document)
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
      if (selected == 'upload') {
        await uploadPdf();
      } else if (selected is RagDocument) {
        selectDocument(selected);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load PDFs: $e')));
      }
    }
  }

  Future<void> showHistory() async {
    if (loading) return;
    try {
      final chats = await widget.repository.assistantChats();
      if (!mounted) return;
      final selected = await showModalBottomSheet<AssistantConversation>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                leading: Icon(Icons.history),
                title: Text('Chat history'),
                subtitle: Text('Saved privately to your administrator account'),
              ),
              const Divider(height: 1),
              if (chats.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No saved conversations yet.'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: chats.length,
                    itemBuilder: (_, index) {
                      final chat = chats[index];
                      final date = chat.updatedAt;
                      return ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(
                          chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Updated ${date.day}/${date.month}/${date.year} '
                          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                        ),
                        trailing: chat.id == conversationId
                            ? const Icon(Icons.check_circle)
                            : const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, chat),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) return;
      setState(() => loading = true);
      final savedMessages = await widget.repository.assistantChat(selected.id);
      RagDocument? savedDocument;
      if (selected.documentId != null) {
        final documents = await widget.repository.documents();
        for (final document in documents) {
          if (document.id == selected.documentId) savedDocument = document;
        }
      }
      if (!mounted) return;
      setState(() {
        conversationId = selected.id;
        selectedDocument = savedDocument;
        messages
          ..clear()
          ..addAll(savedMessages);
      });
      _scrollToLatest();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load chat history: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gemini assistant',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text(
                    'Live attendance, Scan and RTSP context with saved memory.',
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'PDF knowledge',
              onPressed: loading ? null : showDocuments,
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
            IconButton(
              tooltip: 'Chat history',
              onPressed: loading ? null : showHistory,
              icon: const Icon(Icons.history),
            ),
            IconButton(
              tooltip: 'New chat',
              onPressed: loading ? null : newChat,
              icon: const Icon(Icons.add_comment_outlined),
            ),
          ],
        ),
      ),
      if (selectedDocument != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              avatar: const Icon(Icons.description_outlined, size: 18),
              label: Text(selectedDocument!.fileName),
              tooltip: 'Questions are grounded in this PDF',
              onDeleted: loading ? null : clearDocument,
            ),
          ),
        ),
      Expanded(
        child: messages.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.verified_user_outlined),
                      title: Text('Authorized session context'),
                      subtitle: Text(
                        'Answers include observation times and never guess unknown identities or missing visual details.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Suggested questions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestions
                        .map(
                          (question) => ActionChip(
                            avatar: const Icon(Icons.auto_awesome, size: 18),
                            label: Text(question),
                            onPressed: loading ? null : () => ask(question),
                          ),
                        )
                        .toList(),
                  ),
                ],
              )
            : ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: messages.length,
                itemBuilder: (_, index) {
                  final message = messages[index];
                  return Align(
                    alignment: message.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Card(
                      color: message.isUser ? const Color(0xFF3E43A8) : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(message.text),
                      ),
                    ),
                  );
                },
              ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: input,
                  enabled: !loading,
                  maxLength: 1000,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => send(),
                  decoration: const InputDecoration(
                    hintText: 'Ask about attendance, clothing or location...',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: loading ? null : send,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
